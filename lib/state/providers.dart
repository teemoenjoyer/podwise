import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../data/card_repository.dart';
import '../data/database.dart';
import '../data/scryfall_client.dart';
import '../domain/borrowed_game_store.dart';
import '../domain/commander.dart';
import '../domain/counters.dart';
import '../domain/game_timer.dart';
import '../domain/models.dart';
import '../domain/seating.dart';
import 'settings_providers.dart';

const _uuid = Uuid();

/// How long a run of taps stays editable before it is folded into the life
/// total. This is what replaces an undo stack: mis-taps are corrected inside
/// the window rather than reverted afterwards.
const pendingCommitDelay = Duration(seconds: 2);

/// Keeps the screen awake during a game, on a best-effort basis.
///
/// Some devices and OEM power modes refuse the request, and there is no plugin
/// at all under `flutter test`. Neither is worth failing a game over, so a
/// refusal is swallowed: the worst case is the screen dimming as it normally
/// would.
Future<void> _setWakelock(bool enable) async {
  try {
    await (enable ? WakelockPlus.enable() : WakelockPlus.disable());
  } catch (_) {
    // Best effort only.
  }
}

final databaseProvider = Provider<PodWiseDatabase>((ref) {
  final db = PodWiseDatabase();
  ref.onDispose(db.close);
  return db;
});

final scryfallClientProvider = Provider<ScryfallClient>((ref) {
  final client = ScryfallClient();
  ref.onDispose(client.dispose);
  return client;
});

final cardRepositoryProvider = Provider<CardRepository>((ref) {
  return CardRepository(
    ref.watch(databaseProvider),
    ref.watch(scryfallClientProvider),
  );
});

/// Debounced commander search.
///
/// Typing "atraxa" would otherwise fire six requests; waiting for a pause in
/// typing keeps us well inside Scryfall's rate limit and stops results
/// flickering as each keystroke resolves.
final commanderSearchProvider =
    AsyncNotifierProvider<CommanderSearchNotifier, CardSearchResult>(
      CommanderSearchNotifier.new,
    );

class CommanderSearchNotifier extends AsyncNotifier<CardSearchResult> {
  static const _debounce = Duration(milliseconds: 350);

  Timer? _timer;
  String _query = '';

  @override
  Future<CardSearchResult> build() async {
    ref.onDispose(() => _timer?.cancel());
    return const CardSearchResult([], CardSearchSource.network);
  }

  String get query => _query;

  void search(String query) {
    _query = query;
    _timer?.cancel();

    if (query.trim().length < 2) {
      state = const AsyncData(CardSearchResult([], CardSearchSource.network));
      return;
    }

    // Show cached matches immediately so there is something on screen while
    // the network call is in flight.
    _showCachedWhileWaiting(query);

    _timer = Timer(_debounce, () async {
      state = const AsyncLoading<CardSearchResult>().copyWithPrevious(state);
      final legalOnly =
          ref.read(settingsProvider).valueOrNull?.legalCommandersOnly ?? false;
      final result = await ref
          .read(cardRepositoryProvider)
          .search(query, legalOnly: legalOnly);
      // A later keystroke may have superseded this search.
      if (_query == query) state = AsyncData(result);
    });
  }

  Future<void> _showCachedWhileWaiting(String query) async {
    final legalOnly =
        ref.read(settingsProvider).valueOrNull?.legalCommandersOnly ?? false;
    final cached = await ref
        .read(cardRepositoryProvider)
        .searchCacheOnly(query, legalOnly: legalOnly);
    if (_query != query || cached.isEmpty) return;
    if (state.value?.source == CardSearchSource.network &&
        (state.value?.cards.isNotEmpty ?? false)) {
      return;
    }
    state = AsyncData(CardSearchResult(cached, CardSearchSource.cache));
  }

  void clear() {
    _timer?.cancel();
    _query = '';
    state = const AsyncData(CardSearchResult([], CardSearchSource.network));
  }
}

/// Saved players, most recently played first.
final playerProfilesProvider =
    AsyncNotifierProvider<PlayerProfilesNotifier, List<PlayerProfile>>(
      PlayerProfilesNotifier.new,
    );

class PlayerProfilesNotifier extends AsyncNotifier<List<PlayerProfile>> {
  PodWiseDatabase get _db => ref.read(databaseProvider);

  @override
  Future<List<PlayerProfile>> build() => _load();

  Future<List<PlayerProfile>> _load() async {
    final rows = await _db.allProfiles();
    return rows
        .map(
          (r) => PlayerProfile(
            id: r.id,
            name: r.name,
            colorIndex: r.colorIndex,
            lastPlayedAt: r.lastPlayedAt,
          ),
        )
        .toList();
  }

  Future<PlayerProfile> add(String name, int colorIndex) async {
    final profile = PlayerProfile(
      id: _uuid.v4(),
      name: name.trim(),
      colorIndex: colorIndex,
    );
    await _db.upsertProfile(
      PlayerProfileRow(
        id: profile.id,
        name: profile.name,
        colorIndex: profile.colorIndex,
        createdAt: DateTime.now(),
      ),
    );
    state = AsyncData(await _load());
    return profile;
  }

  Future<void> rename(PlayerProfile profile, String name) async {
    // A targeted update rather than an upsert, which would have reset the
    // profile's creation date on every rename.
    await _db.renameProfile(profile.id, name.trim());
    state = AsyncData(await _load());
    // History carries its own copy of the name, so it has to be re-read.
    ref.invalidate(gameHistoryProvider);
  }

  /// Removes a player, their decks, and nothing else.
  ///
  /// Anything derived from their decks refreshes on its own: the deck list
  /// watches this provider, so replacing the state here is enough.
  Future<void> remove(PlayerProfile profile) async {
    await _db.deleteProfile(profile.id);
    state = AsyncData(await _load());
  }
}

/// Holds the profile id of a player who has just dropped to 0 or below and
/// needs an elimination decision, or null when there is nothing to ask.
///
/// Reaching 0 life is not itself a loss in Commander, but in practice it
/// almost always ends that player's game — so the app asks rather than either
/// assuming or staying silent.
final eliminationPromptProvider = StateProvider<String?>((ref) => null);

/// The game in progress, or null when there isn't one.
final activeGameProvider = NotifierProvider<ActiveGameNotifier, GameState?>(
  ActiveGameNotifier.new,
);

class ActiveGameNotifier extends Notifier<GameState?> {
  final Map<String, int> _pending = {};
  final Map<String, Timer> _timers = {};

  /// Players already asked about since they last went above 0. Prevents the
  /// prompt reappearing every time a player at negative life takes more damage.
  final Set<String> _zeroPrompted = {};

  PodWiseDatabase get _db => ref.read(databaseProvider);

  @override
  GameState? build() {
    ref.onDispose(() {
      for (final t in _timers.values) {
        t.cancel();
      }
      _saveDebounce?.cancel();
      unawaited(_setWakelock(false));
    });

    // A borrowed game left over from a previous run is picked back up. Nobody
    // else has a copy of it, so dropping it on a restart would lose the pod's
    // result with no way to recover it.
    unawaited(_restoreBorrowed());
    return null;
  }

  Timer? _saveDebounce;

  Future<void> _restoreBorrowed() async {
    final stored = (await _db.allSettings())[BorrowedGameStore.key];
    final game = BorrowedGameStore.decode(stored);
    // Only if nothing has started in the meantime — a restored game must never
    // displace one the user is actually playing.
    if (game == null || state != null) return;
    state = game;
    if (!game.isFinished) unawaited(_setWakelock(true));
  }

  /// Writes a borrowed game out, coalescing the burst of changes a run of taps
  /// produces into one write.
  void _persistBorrowed() {
    final game = state;
    if (game == null || !game.isBorrowed) return;

    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 400), () {
      final current = state;
      if (current == null || !current.isBorrowed) return;
      unawaited(
        _db.putSetting(
          BorrowedGameStore.key,
          BorrowedGameStore.encode(current),
        ),
      );
    });
  }

  Future<void> _forgetBorrowed() async {
    _saveDebounce?.cancel();
    await _db.putSetting(BorrowedGameStore.key, '');
  }

  // Every mutation in this class goes through the state setter, so hooking it
  // here means a new one cannot forget to persist itself.
  @override
  set state(GameState? value) {
    super.state = value;
    _persistBorrowed();
  }

  /// Uncommitted life change for a seat, or 0. Drives the floating "+5"
  /// indicator on the panel.
  int pendingFor(String profileId) => _pending[profileId] ?? 0;

  void start({
    required List<PlayerProfile> players,
    required int startingLife,
    Map<String, CommanderSet> commanders = const {},
    /// What each player's commander is called, for decks that name one
    /// without the app holding the card. Ignored where real cards arrived.
    Map<String, String> commanderLabels = const {},
    Map<String, String> deckIds = const {},
    String? borrowedFrom,
    String? gameId,
    bool deckRoulette = false,
  }) {
    _clearPending();
    final now = DateTime.now();
    state = GameState(
      // A borrowed game carries an id minted here and echoed home in the
      // result, which is what lets the other phone reject a second import.
      id: gameId ?? _uuid.v4(),
      borrowedFrom: borrowedFrom,
      deckRoulette: deckRoulette,
      startingLife: startingLife,
      startedAt: now,
      // Running from the moment the game does. Nobody wants to remember to
      // start a stopwatch, and a clock you have to notice is a clock that
      // gets forgotten — so it counts whether or not it is on screen.
      timer: const GameTimer().start(now),
      seats: [
        for (final p in players)
          Seat(
            profileId: p.id,
            name: p.name,
            colorIndex: p.colorIndex,
            life: startingLife,
            deckId: deckIds[p.id],
            commanders: commanders[p.id] ?? const CommanderSet.empty(),
            commanderLabel: commanderLabels[p.id],
          ),
      ],
    );
    // A phone acting as the table's life counter must not sleep mid-game.
    unawaited(_setWakelock(true));
  }

  /// Records a life change as *pending*. Repeated taps accumulate and the
  /// commit timer restarts, so a burst of taps lands as one change.
  void adjustLife(String profileId, int delta) {
    final game = state;
    if (game == null) return;

    _pending[profileId] = (_pending[profileId] ?? 0) + delta;
    _timers[profileId]?.cancel();
    _timers[profileId] = Timer(pendingCommitDelay, () => commit(profileId));

    // Reflect the change immediately — the pending window is about editing,
    // not about hiding the number from the table.
    state = game.copyWith(
      seats: [
        for (final s in game.seats)
          s.profileId == profileId ? s.copyWith(life: s.life + delta) : s,
      ],
    );
  }

  /// Folds any pending change into the committed total.
  void commit(String profileId) {
    _timers.remove(profileId)?.cancel();
    _pending.remove(profileId);
    // Life is already applied; committing only clears the editable window.
    state = state?.copyWith();
    _maybeAskAboutElimination(profileId);
  }

  /// Asks about elimination once a player settles somewhere fatal.
  ///
  /// Zero life is the usual way, but a lethal counter — ten poison — means the
  /// same thing and deserves the same prompt. It is still only a prompt:
  /// Commander has too many loss conditions for the app to decide.
  ///
  /// Deliberately runs on commit rather than on each tap: tapping −1 five
  /// times from 3 life should not interrupt the run at zero.
  void _maybeAskAboutElimination(String profileId) {
    final game = state;
    if (game == null) return;

    final seat = game.seats.where((s) => s.profileId == profileId).firstOrNull;
    if (seat == null || seat.eliminated) return;

    final lethalCounter = CounterPresets.all.any(
      (counter) => counter.isLethal(seat.counters[counter.id] ?? 0),
    );

    // Twenty-one from one commander is lethal on its own. It is not implied by
    // life reaching zero either: twenty-one taken from a full forty leaves a
    // player on nineteen, so without this the game would simply carry on.
    final lethalCommander = game.isLethalCommanderDamage(profileId);

    if (seat.life > 0 && !lethalCounter && !lethalCommander) {
      // Back out of danger — a later trip into it should ask again.
      _zeroPrompted.remove(profileId);
      return;
    }

    // Set.add returns false when already present, so this asks exactly once.
    if (_zeroPrompted.add(profileId)) {
      ref.read(eliminationPromptProvider.notifier).state = profileId;
    }
  }

  void commitAll() {
    for (final id in _pending.keys.toList()) {
      commit(id);
    }
  }

  /// Records commander damage from one commander to one player.
  ///
  /// Commander damage is also normal damage, so this reduces life by the same
  /// amount — forgetting that is the most common mistake in life trackers, and
  /// it silently desyncs the board from reality.
  void adjustCommanderDamage({
    required String sourceCardId,
    required String targetProfileId,
    required int delta,
  }) {
    final game = state;
    if (game == null) return;

    final key = CommanderDamageKey(
      sourceCardId: sourceCardId,
      targetProfileId: targetProfileId,
    );
    final current = game.commanderDamage[key] ?? 0;
    // Damage cannot go below zero; correcting an over-tap should not create
    // negative damage that later additions have to climb out of.
    final next = (current + delta).clamp(0, 999);
    final applied = next - current;
    if (applied == 0) return;

    state = game.copyWith(
      commanderDamage: {...game.commanderDamage, key: next},
      seats: [
        for (final s in game.seats)
          s.profileId == targetProfileId
              ? s.copyWith(life: s.life - applied)
              : s,
      ],
    );

    _maybeAskAboutElimination(targetProfileId);
  }

  /// Adjusts a numeric counter on a player.
  ///
  /// Counters never go below zero — negative poison is meaningless, and an
  /// over-tap should settle at zero rather than bank a debt.
  void adjustCounter(String profileId, String counterId, int delta) {
    final game = state;
    if (game == null) return;

    state = game.copyWith(
      seats: [
        for (final s in game.seats)
          if (s.profileId == profileId)
            s.copyWith(
              counters: {
                ...s.counters,
                counterId: ((s.counters[counterId] ?? 0) + delta).clamp(0, 999),
              },
            )
          else
            s,
      ],
    );

    // Ten poison ends a game as surely as zero life does.
    _maybeAskAboutElimination(profileId);
  }

  void removeCounter(String profileId, String counterId) {
    final game = state;
    if (game == null) return;
    state = game.copyWith(
      seats: [
        for (final s in game.seats)
          if (s.profileId == profileId)
            s.copyWith(counters: {...s.counters}..remove(counterId))
          else
            s,
      ],
    );
  }

  /// Toggles a status effect.
  ///
  /// Exclusive statuses (Monarch, Initiative) move to the new holder rather
  /// than being held by two players at once, and Day/Night replace each other.
  void toggleStatus(String profileId, StatusEffect status) {
    final game = state;
    if (game == null) return;

    final seat = game.seats.where((s) => s.profileId == profileId).firstOrNull;
    if (seat == null) return;
    final turningOn = !seat.statuses.contains(status.id);
    final opposite = StatusPresets.opposite(status.id);

    state = game.copyWith(
      seats: [
        for (final s in game.seats)
          s.copyWith(
            statuses: _nextStatuses(
              current: s.statuses,
              isTarget: s.profileId == profileId,
              status: status,
              turningOn: turningOn,
              opposite: opposite,
            ),
          ),
      ],
    );
  }

  /// Works out one seat's statuses after a toggle elsewhere at the table.
  static Set<String> _nextStatuses({
    required Set<String> current,
    required bool isTarget,
    required StatusEffect status,
    required bool turningOn,
    required String? opposite,
  }) {
    final next = {...current};

    // Day and Night replace each other everywhere, since they describe the
    // game rather than a single player.
    if (turningOn && opposite != null) next.remove(opposite);

    if (isTarget) {
      turningOn ? next.add(status.id) : next.remove(status.id);
    } else if (status.exclusive && turningOn) {
      // Only one player can be the Monarch; taking it removes it from whoever
      // held it before.
      next.remove(status.id);
    }

    return next;
  }

  // ---- Game timer ---------------------------------------------------------

  void toggleTimer() {
    final game = state;
    if (game == null) return;
    state = game.copyWith(timer: game.timer.toggle(DateTime.now()));
  }

  void resetTimer() {
    final game = state;
    if (game == null) return;
    state = game.copyWith(timer: game.timer.reset());
  }

  /// Sets a player's commander loadout mid-game.
  void setCommanders(String profileId, CommanderSet commanders) {
    final game = state;
    if (game == null) return;
    state = game.copyWith(
      seats: [
        for (final s in game.seats)
          s.profileId == profileId ? s.copyWith(commanders: commanders) : s,
      ],
    );
  }

  /// Records the outcome of the first-turn draw.
  ///
  /// A null [profileId] means the table skipped it, which is still an answer —
  /// it stops the draw being offered again for this game.
  void recordFirstPlayerDraw(String? profileId) {
    final game = state;
    if (game == null) return;
    state = game.copyWith(firstPlayerId: profileId, firstPlayerAsked: true);
  }

  /// Rearranges the table: [farRowSeats] players opposite, the rest near.
  ///
  /// Seats keep their order, so nobody's life total follows them across the
  /// board — the panels are simply dealt into different rows.
  void setSeating(int farRowSeats) {
    final game = state;
    if (game == null) return;
    state = game.copyWith(
      farRowSeats: farRowSeats.clamp(0, game.seats.length),
    );
  }

  /// Swaps who sits in seats [a] and [b].
  ///
  /// For a table that sorted out its seats after the game started. Everything
  /// about a player is keyed by their id, so their life, counters, commander
  /// damage and place in the knockout order all move with them.
  void swapSeats(int a, int b) {
    final game = state;
    if (game == null) return;
    state = game.copyWith(seats: Seating.swap(game.seats, a, b));
  }

  /// Moves everybody round one seat.
  void rotateSeats() {
    final game = state;
    if (game == null) return;
    state = game.copyWith(seats: Seating.rotate(game.seats));
  }

  void setLife(String profileId, int life) {
    final game = state;
    if (game == null) return;
    commit(profileId);
    state = game.copyWith(
      seats: [
        for (final s in game.seats)
          s.profileId == profileId ? s.copyWith(life: life) : s,
      ],
    );
  }

  /// Elimination is always explicit. Commander has many loss conditions, so
  /// reaching zero life is a prompt, never an automatic knockout.
  ///
  /// The *last* elimination is different: once one player is left standing
  /// there is nothing to decide, so the game ends itself.
  void toggleEliminated(String profileId) {
    final game = state;
    if (game == null || game.isFinished) return;

    final seat = game.seats.firstWhere((s) => s.profileId == profileId);

    // One past the highest order handed out so far, rather than a count of
    // who is currently out. Counting breaks as soon as somebody is put back
    // in: knock out A then B, revive A, knock out C, and C would be handed
    // B's number — leaving two players tied for the same finishing place.
    final nextOrder =
        game.seats
            .map((s) => s.eliminationOrder)
            .whereType<int>()
            .fold(-1, (highest, order) => order > highest ? order : highest) +
        1;

    state = game.copyWith(
      seats: [
        for (final s in game.seats)
          if (s.profileId == profileId)
            s.copyWith(
              eliminated: !seat.eliminated,
              eliminationOrder: seat.eliminated ? null : nextOrder,
              clearEliminationOrder: seat.eliminated,
            )
          else
            s,
      ],
    );

    // Everybody but one is out, so that player has won — no need to make them
    // go and find the menu to say so.
    final settled = state;
    if (settled != null && !settled.isFinished && settled.hasSoleSurvivor) {
      unawaited(finish());
    }
  }

  void resetLife() {
    final game = state;
    if (game == null) return;
    _clearPending();
    state = game.copyWith(
      seats: [
        for (final s in game.seats)
          s.copyWith(
            life: game.startingLife,
            eliminated: false,
            clearEliminationOrder: true,
          ),
      ],
    );
  }

  /// Ends the game, writes it to history, and releases the wakelock.
  Future<void> finish({String? winnerProfileId}) async {
    final game = state;
    if (game == null) return;
    commitAll();

    final finishedAt = DateTime.now();
    final winner = game.resolveWinner(winnerProfileId);
    final ranked = game.rankedBy(winner);

    // A borrowed pod belongs to another phone's playgroup. Writing it here
    // would put strangers into this phone's history, statistics and matchup
    // counts permanently; it travels home as a code instead.
    if (game.isBorrowed) {
      state = game.copyWith(finishedAt: finishedAt, winnerProfileId: winner);
      await _setWakelock(false);
      return;
    }

    await _db.saveFinishedGame(
      game: GameRow(
        id: game.id,
        startedAt: game.startedAt,
        finishedAt: finishedAt,
        startingLife: game.startingLife,
        deckRoulette: game.deckRoulette,
        winnerProfileId: winner,
      ),
      participants: [
        for (var i = 0; i < ranked.length; i++)
          GameParticipantsCompanion(
            gameId: Value(game.id),
            profileId: Value(ranked[i].profileId),
            name: Value(ranked[i].name),
            seatIndex: Value(
              game.seats.indexWhere((s) => s.profileId == ranked[i].profileId),
            ),
            colorIndex: Value(ranked[i].colorIndex),
            finalLife: Value(ranked[i].life),
            deckId: Value(ranked[i].deckId),
            position: Value(i + 1),
            eliminated: Value(ranked[i].eliminated),
          ),
      ],
    );

    state = game.copyWith(finishedAt: finishedAt, winnerProfileId: winner);
    await _setWakelock(false);
    ref.invalidate(playerProfilesProvider);
    ref.invalidate(gameHistoryProvider);
  }

  void clear() {
    _clearPending();
    final wasBorrowed = state?.isBorrowed ?? false;
    state = null;
    // Deliberately not cleared when a borrowed game merely finishes: the code
    // on the result screen is the only copy of it, and the phone showing it
    // may well be backgrounded before anyone scans.
    if (wasBorrowed) unawaited(_forgetBorrowed());
    unawaited(_setWakelock(false));
  }

  void _clearPending() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    _pending.clear();
    _zeroPrompted.clear();
  }
}

/// Finished games, newest first.
final gameHistoryProvider = FutureProvider<List<GameRecord>>((ref) async {
  final db = ref.watch(databaseProvider);
  final games = await db.recentGames();
  return [
    for (final g in games)
      GameRecord(
        id: g.id,
        startedAt: g.startedAt,
        finishedAt: g.finishedAt!,
        startingLife: g.startingLife,
        winnerProfileId: g.winnerProfileId,
        // Finishing order, not seat order. The rows come back seated, which is
        // how they are stored, but a history card is read to find out how the
        // night went.
        results: [
          for (final p
              in (await db.participantsOf(g.id)).toList()..sort(
                (a, b) => (a.position ?? 99).compareTo(b.position ?? 99),
              ))
            GameResult(
              profileId: p.profileId,
              name: p.name,
              finalLife: p.finalLife,
              position: p.position ?? 0,
              won: p.profileId == g.winnerProfileId,
            ),
        ],
      ),
  ];
});

/// How many cards are cached for offline search.
final cachedCardCountProvider = FutureProvider<int>((ref) {
  return ref.watch(cardRepositoryProvider).cachedCount();
});

/// The card whose art represents a deck, from the offline cache.
///
/// Keyed on the ids joined with a comma rather than on the list itself: a
/// family key has to compare by value, and two equal lists are not equal in
/// Dart, so a list key would rebuild and refetch on every build.
///
/// Resolves to null for a deck with no cards — which includes any deck the
/// v9 relink could not match, so every caller needs a fallback.
final deckArtProvider = FutureProvider.family<MagicCard?, String>((
  ref,
  commanderIds,
) async {
  if (commanderIds.isEmpty) return null;
  final set = await ref
      .watch(cardRepositoryProvider)
      .commanderSet(commanderIds.split(','));
  return set.primary;
});

/// Who painted a card, for crediting art that is already on screen.
///
/// Keyed by the card because [MagicCard] compares by id, so two screens
/// showing the same commander share one lookup. Deliberately separate from
/// the art itself: the picture appears immediately from cache and the credit
/// catches up, rather than the screen waiting on the network to draw.
final cardArtistProvider = FutureProvider.family<String?, MagicCard>((
  ref,
  card,
) {
  return ref.watch(cardRepositoryProvider).artistOf(card);
});

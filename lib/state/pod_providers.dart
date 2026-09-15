import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../data/database.dart';
import '../domain/commander.dart';
import '../domain/deck_roulette.dart';
import '../domain/models.dart';
import '../domain/pod.dart';
import '../domain/pod_builder.dart';
import 'providers.dart';

const _uuid = Uuid();

/// Every saved deck, with the record that deck has earned.
///
/// Results are attributed per deck rather than per player: someone who brings
/// a precon one week and a tuned list the next has two very different win
/// rates, and averaging them would mislead the Pod Builder about both.
final allDecksProvider = FutureProvider<List<DeckProfile>>((ref) async {
  final db = ref.watch(databaseProvider);
  final players = await ref.watch(playerProfilesProvider.future);
  // A deck's record is derived from finished games, so this genuinely depends
  // on game history — watching it is what refreshes records when a game ends.
  await ref.watch(gameHistoryProvider.future);
  final rows = await db.allDecks();
  final records = await db.deckRecords();
  final byId = {for (final p in players) p.id: p};

  return [
    for (final row in rows)
      // A deck whose owner has been deleted is dropped rather than shown
      // ownerless.
      if (byId[row.playerId] case final player?)
        _toDeckProfile(player, row, records[row.id]),
  ];
});

/// Each player alongside their deck library.
///
/// A player who has saved no decks still appears, carrying a single unsaved
/// placeholder — the Pod Builder must work on the first night, before anyone
/// has entered anything.
typedef PlayerDecks = ({PlayerProfile player, List<DeckProfile> decks});

final playerDecksProvider = FutureProvider<List<PlayerDecks>>((ref) async {
  final players = await ref.watch(playerProfilesProvider.future);
  final decks = await ref.watch(allDecksProvider.future);

  final byPlayer = <String, List<DeckProfile>>{};
  for (final deck in decks) {
    byPlayer.putIfAbsent(deck.playerId, () => []).add(deck);
  }

  return [
    for (final player in players)
      (player: player, decks: byPlayer[player.id] ?? [placeholderDeck(player)]),
  ];
});

/// The stand-in shown for a player with no saved decks. It has no id, so
/// saving it creates a real deck rather than overwriting one.
DeckProfile placeholderDeck(PlayerProfile player) =>
    DeckProfile(playerId: player.id, playerName: player.name);

DeckProfile _toDeckProfile(
  PlayerProfile player,
  DeckRow row,
  ({int games, int wins})? record,
) => DeckProfile(
  playerId: player.id,
  playerName: player.name,
  deckId: row.id,
  deckName: row.name,
  commanderName: row.commanderName,
  commanderIds: _splitIds(row.commanderIds),
  colorIdentity: _parseColors(row.colorIdentity),
  power: row.power,
  archetypes: _parseEnum(row.archetypes, DeckArchetype.values),
  interaction: _parseEnum(row.interaction, InteractionType.values),
  gamesPlayed: record?.games ?? 0,
  wins: record?.wins ?? 0,
  lastPlayedAt: row.lastPlayedAt,
);

List<String> _splitIds(String raw) =>
    raw.isEmpty ? const [] : raw.split(',').where((s) => s.isNotEmpty).toList();

Set<ManaColor> _parseColors(String raw) => {
  for (final ch in raw.split('')) ?ManaColor.fromCode(ch),
};

/// Enum values survive a rename in the codebase gracefully: an unknown name in
/// the database is dropped rather than crashing the whole profile.
Set<T> _parseEnum<T extends Enum>(String? raw, List<T> values) {
  if (raw == null || raw.isEmpty) return {};
  final byName = {for (final v in values) v.name: v};
  return {for (final part in raw.split(',')) ?byName[part.trim()]};
}

/// Creates, updates and deletes decks.
final deckEditorProvider = Provider((ref) => DeckEditor(ref));

class DeckEditor {
  DeckEditor(this._ref);
  final Ref _ref;

  PodWiseDatabase get _db => _ref.read(databaseProvider);

  /// Writes a deck, creating it if it has no id yet. Returns the saved deck,
  /// which for a new one carries the id it was given.
  Future<DeckProfile> save(DeckProfile deck) async {
    final id = deck.isSaved ? deck.deckId : _uuid.v4();
    final existing = deck.isSaved ? await _row(id) : null;
    final now = DateTime.now();

    await _db.upsertDeck(
      DeckRow(
        id: id,
        playerId: deck.playerId,
        name: deck.deckName,
        commanderName: deck.commanderName,
        commanderIds: deck.commanderIds.join(','),
        colorIdentity: deck.colorIdentity.map((c) => c.code).join(),
        power: deck.power,
        archetypes: deck.archetypes.map((a) => a.name).join(','),
        interaction: deck.interaction.map((i) => i.name).join(','),
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
        lastPlayedAt: existing?.lastPlayedAt,
      ),
    );
    _invalidate();
    return deck.copyWith(deckId: id);
  }

  Future<void> delete(String deckId) async {
    await _db.deleteDeck(deckId);
    _invalidate();
  }

  /// Finds the deck a player is bringing, given what they put in the command
  /// zone, creating one if this commander is new to them.
  ///
  /// Matching is by commander card ids, so picking the same commander again
  /// returns the existing deck with its power rating and record intact rather
  /// than quietly starting a second, empty copy of it.
  Future<DeckProfile?> deckForCommanders(
    PlayerProfile player,
    CommanderSet commanders,
  ) async {
    if (commanders.isEmpty) return null;
    final ids = commanders.cards.map((c) => c.id).toList();

    final owned = (await _db.allDecks())
        .where((row) => row.playerId == player.id)
        .toList();

    final existing =
        owned
            .where((row) => _sameCommanders(_splitIds(row.commanderIds), ids))
            .firstOrNull ??
        // Decks carried over from before ids were stored have only a name to
        // match on. Matching it here is what stops the first game after the
        // upgrade silently creating a duplicate of a deck they already own.
        owned
            .where(
              (row) =>
                  row.commanderIds.isEmpty &&
                  row.commanderName == commanders.displayName,
            )
            .firstOrNull;

    if (existing != null) {
      final deck = _toDeckProfile(player, existing, null);
      // Backfill the ids so the next lookup matches properly, and so this
      // deck can restore its own command zone.
      if (existing.commanderIds.isEmpty) {
        return save(deck.copyWith(commanderIds: ids));
      }
      return deck;
    }

    return save(
      DeckProfile(
        playerId: player.id,
        playerName: player.name,
        commanderName: commanders.displayName,
        commanderIds: ids,
        colorIdentity: commanders.colorIdentity,
      ),
    );
  }

  /// Records that these decks were just played, so they lead their owner's
  /// list next time.
  Future<void> markPlayed(List<String> deckIds, DateTime when) async {
    if (deckIds.isEmpty) return;
    await _db.touchDecks(deckIds, when);
    _invalidate();
  }

  Future<DeckRow?> _row(String id) async =>
      (await _db.allDecks()).where((r) => r.id == id).firstOrNull;

  void _invalidate() => _ref.invalidate(allDecksProvider);

  /// Order is irrelevant to identity — a partner pair is the same deck
  /// whichever commander was tapped first.
  static bool _sameCommanders(List<String> a, List<String> b) =>
      a.length == b.length && a.toSet().containsAll(b);
}

/// Pairwise play history, for Fresh Matchups scoring.
final matchupHistoryProvider = FutureProvider<MatchupHistory>((ref) async {
  return ref.watch(databaseProvider).matchupCounts();
});

/// The current pod-building session: who is playing, with which deck, in which
/// mode, and the ranked assignments produced.
class PodSession {
  const PodSession({
    this.selectedIds = const {},
    this.deckByPlayer = const {},
    this.rouletteDecks = const {},
    this.mode = PodMode.smartPods,
    this.podCount,
    this.assignments = const [],
    this.shownIndex = 0,
    this.building = false,
  });

  final Set<String> selectedIds;

  /// Which deck each player is bringing tonight, by player id. Absent means
  /// "their most recent one", which is right far more often than not.
  final Map<String, String> deckByPlayer;

  /// In Deck Roulette, the deck each player has been handed — somebody else's,
  /// by player id. Empty in every other mode.
  final Map<String, DeckProfile> rouletteDecks;

  final PodMode mode;

  /// Null means "work it out from the player count".
  final int? podCount;

  /// Ranked alternatives, best first.
  final List<PodAssignment> assignments;

  /// Which alternative is on screen. REBUILD steps through these.
  final int shownIndex;

  final bool building;

  PodAssignment? get current =>
      assignments.isEmpty ? null : assignments[shownIndex % assignments.length];

  bool get canBuild => selectedIds.length >= 2;

  /// The deck this player is bringing, out of the ones they own.
  DeckProfile deckFor(PlayerDecks entry) {
    final chosen = deckByPlayer[entry.player.id];
    return entry.decks.firstWhere(
      (d) => d.deckId == chosen,
      // [playerDecksProvider] guarantees at least a placeholder, and the list
      // is already ordered most-recently-played first.
      orElse: () => entry.decks.first,
    );
  }

  PodSession copyWith({
    Set<String>? selectedIds,
    Map<String, String>? deckByPlayer,
    Map<String, DeckProfile>? rouletteDecks,
    PodMode? mode,
    int? podCount,
    bool clearPodCount = false,
    List<PodAssignment>? assignments,
    int? shownIndex,
    bool? building,
  }) => PodSession(
    selectedIds: selectedIds ?? this.selectedIds,
    deckByPlayer: deckByPlayer ?? this.deckByPlayer,
    rouletteDecks: rouletteDecks ?? this.rouletteDecks,
    mode: mode ?? this.mode,
    podCount: clearPodCount ? null : (podCount ?? this.podCount),
    assignments: assignments ?? this.assignments,
    shownIndex: shownIndex ?? this.shownIndex,
    building: building ?? this.building,
  );
}

final podSessionProvider = NotifierProvider<PodSessionNotifier, PodSession>(
  PodSessionNotifier.new,
);

class PodSessionNotifier extends Notifier<PodSession> {
  @override
  PodSession build() => const PodSession();

  void toggle(String playerId) {
    final next = {...state.selectedIds};
    next.contains(playerId) ? next.remove(playerId) : next.add(playerId);
    // Any change to who is playing invalidates the pods already built, and
    // the decks that were dealt to them.
    state = state.copyWith(
      selectedIds: next,
      assignments: [],
      shownIndex: 0,
      rouletteDecks: const {},
    );
  }

  /// Picks which deck a player is bringing. Changing it changes the power and
  /// colours being balanced, so the built pods no longer apply.
  void chooseDeck(String playerId, String deckId) {
    state = state.copyWith(
      deckByPlayer: {...state.deckByPlayer, playerId: deckId},
      assignments: [],
      shownIndex: 0,
    );
  }

  void setMode(PodMode mode) {
    state = state.copyWith(
      mode: mode,
      assignments: [],
      shownIndex: 0,
      rouletteDecks: const {},
    );
  }

  void setPodCount(int? count) {
    state = state.copyWith(
      podCount: count,
      clearPodCount: count == null,
      assignments: [],
      shownIndex: 0,
    );
  }

  Future<void> buildPods() async {
    if (!state.canBuild) return;
    state = state.copyWith(building: true);

    final roster = await ref.read(playerDecksProvider.future);
    final history = await ref.read(matchupHistoryProvider.future);
    final players = [
      for (final entry in roster)
        if (state.selectedIds.contains(entry.player.id)) state.deckFor(entry),
    ];

    final assignments = PodBuilder.build(
      players: players,
      mode: state.mode,
      history: history,
      podCount: state.podCount,
    );

    state = state.copyWith(
      assignments: assignments,
      shownIndex: 0,
      building: false,
      rouletteDecks: state.mode.swapsDecks
          ? DeckRoulette.deal(
              playerIds: [for (final p in players) p.playerId],
              // Everybody's decks, not just the one they were bringing —
              // rummaging through the whole group's shelf is the point.
              pool: await ref.read(allDecksProvider.future),
            )
          : const {},
    );
  }

  /// Hands one player a different deck, leaving the rest of the table alone.
  Future<void> rerollDeck(String playerId) async {
    if (!state.mode.swapsDecks) return;
    state = state.copyWith(
      rouletteDecks: DeckRoulette.reroll(
        playerId: playerId,
        current: state.rouletteDecks,
        pool: await ref.read(allDecksProvider.future),
      ),
    );
  }

  /// Shows the next-best assignment rather than recomputing the same one.
  void rebuild() {
    if (state.assignments.length < 2) {
      // Only one distinct option, so recompute and let the shuffle move people.
      buildPods();
      return;
    }
    state = state.copyWith(shownIndex: state.shownIndex + 1);
  }

  void clear() => state = const PodSession();
}

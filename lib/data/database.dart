import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

/// Saved people. Kept separate from per-game rows so statistics can accumulate
/// across games and, later, feed the Pod Builder.
///
/// Row classes carry a `Row` suffix throughout so they never collide with the
/// domain models in `domain/models.dart`, which share the same concepts.
@DataClassName('PlayerProfileRow')
class PlayerProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text().withLength(min: 1, max: 40)();
  IntColumn get colorIndex => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastPlayedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('GameRow')
class Games extends Table {
  TextColumn get id => text()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get finishedAt => dateTime().nullable()();
  IntColumn get startingLife => integer()();
  TextColumn get winnerProfileId => text().nullable()();

  /// True when everybody was playing somebody else's deck.
  ///
  /// These games count for the players but never for the decks: a deck's
  /// power rating is about how the deck plays in its owner's hands, and a
  /// stranger piloting it says nothing about that either way.
  BoolColumn get deckRoulette => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

/// One row per player per game.
@DataClassName('GameParticipantRow')
class GameParticipants extends Table {
  IntColumn get rowId => integer().autoIncrement()();
  TextColumn get gameId => text().references(Games, #id)();
  TextColumn get profileId => text()();

  /// Denormalised so history stays readable if a profile is later renamed.
  TextColumn get name => text()();
  IntColumn get seatIndex => integer()();
  IntColumn get colorIndex => integer()();
  IntColumn get finalLife => integer()();

  /// Which of the player's decks was brought. Null for games recorded before
  /// decks existed, or for a game started without picking a commander.
  TextColumn get deckId => text().nullable()();

  /// 1 = won. Null until the game finishes.
  IntColumn get position => integer().nullable()();

  BoolColumn get eliminated => boolean().withDefault(const Constant(false))();
}

/// Cards retrieved from Scryfall, kept so the app keeps working at a table
/// with no signal. Search falls back to these rows when the network fails.
@DataClassName('CachedCardRow')
class CachedCards extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();

  /// Lowercased name, so offline search can do a cheap LIKE without
  /// per-row case conversion.
  TextColumn get searchName => text()();
  TextColumn get typeLine => text()();

  /// Colour identity as WUBRG letters, e.g. "WUBG". Empty means colourless.
  TextColumn get colorIdentity => text().withDefault(const Constant(''))();
  TextColumn get oracleText => text().nullable()();
  TextColumn get manaCost => text().nullable()();
  TextColumn get imageSmall => text().nullable()();
  TextColumn get imageNormal => text().nullable()();
  TextColumn get imageArtCrop => text().nullable()();
  TextColumn get scryfallUri => text().nullable()();

  /// Credited wherever the art is shown.
  TextColumn get artist => text().nullable()();

  DateTimeColumn get cachedAt => dateTime()();

  /// Bumped whenever the card is chosen, so the most-used commanders sort
  /// first offline.
  IntColumn get useCount => integer().withDefault(const Constant(0))();

  /// False for silver-bordered and other non-sanctioned cards.
  BoolColumn get commanderLegal =>
      boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}

/// One deck in a player's library, as the group understands it.
///
/// A player owns as many of these as they like. Power, archetypes and results
/// all belong to the deck rather than the person — someone who plays both a
/// precon and a tuned cEDH list is two very different opponents depending on
/// which one they brought.
@DataClassName('DeckRow')
class Decks extends Table {
  TextColumn get id => text()();
  TextColumn get playerId => text()();

  /// Optional nickname. Empty means the deck goes by its commander, which is
  /// how most players refer to their decks anyway.
  TextColumn get name => text().withDefault(const Constant(''))();

  TextColumn get commanderName => text().withDefault(const Constant(''))();

  /// Comma-separated Scryfall ids for the command zone, so the cards can be
  /// rehydrated from the offline cache when this deck is brought to a game.
  /// Commander damage is tracked per card, so the names alone are not enough.
  TextColumn get commanderIds => text().withDefault(const Constant(''))();

  /// WUBRG letters, empty for colourless.
  TextColumn get colorIdentity => text().withDefault(const Constant(''))();

  /// 1-10 as judged by the group.
  IntColumn get power => integer().withDefault(const Constant(5))();

  /// Comma-separated [DeckArchetype] names.
  TextColumn get archetypes => text().withDefault(const Constant(''))();

  /// Comma-separated [InteractionType] names.
  TextColumn get interaction => text().withDefault(const Constant(''))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// Used to pick the deck a player most likely wants next.
  DateTimeColumn get lastPlayedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Key-value app settings.
///
/// A table rather than shared_preferences so everything the app remembers
/// lives in one file, backs up together, and needs no extra plugin.
@DataClassName('SettingRow')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    PlayerProfiles,
    Games,
    GameParticipants,
    CachedCards,
    Decks,
    Settings,
  ],
)
class PodWiseDatabase extends _$PodWiseDatabase {
  PodWiseDatabase() : super(_openConnection());

  /// Visible for testing — lets tests run against an in-memory database.
  PodWiseDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => m.createAll(),
    onUpgrade: (m, from, to) async {
      // Each step is additive. Existing installs already have games and
      // players that must survive every upgrade.
      if (from < 2) {
        // v2 introduced the offline card cache.
        await m.createTable(cachedCards);
      }
      // v3 introduced a single deck profile per player. That table no longer
      // exists in the Dart schema — the v6 step below reads whatever is there
      // and replaces it with the deck library, so there is nothing to create
      // here for an install that never had one.

      if (from < 4) {
        // v4 introduced app settings.
        await m.createTable(settings);
      }
      if (from < 5) {
        // v5 records whether a cached card is commander-legal.
        await m.addColumn(cachedCards, cachedCards.commanderLegal);
      }
      if (from < 6) {
        // v6 replaces the one-deck-per-player profile with a deck library,
        // and records which deck was played in each game.
        await m.createTable(decks);
        await m.addColumn(gameParticipants, gameParticipants.deckId);
        await _migrateDeckProfilesToDecks(m);
      }
      if (from < 7) {
        // v7 marks games where everybody swapped decks.
        await m.addColumn(games, games.deckRoulette);
      }
      if (from < 8) {
        // v8 credits the artist wherever card art is shown. Cards already
        // in the cache have no artist until they are looked up again, so
        // every caller has to treat it as optional.
        await m.addColumn(cachedCards, cachedCards.artist);
      }
      if (from < 9) {
        // v9 reconnects decks that know their commander's name but not its
        // card id. Unlike every step before it this rewrites existing rows,
        // so it is deliberately cautious — see relinkLegacyCommanders.
        await relinkLegacyCommanders();
      }
    },
  );

  /// Reconnects decks that know their commander's name but not its card id.
  ///
  /// The v6 upgrade built the deck library out of the old one-deck-per-player
  /// table, which only ever stored a commander's *name* — card ids did not
  /// exist yet. Those decks show their commander in every place a name is
  /// enough, and nowhere the card itself is needed: no art, and commander
  /// damage tracked against a stand-in source rather than the real card.
  ///
  /// Matching is by exact name against the local card cache, so it needs no
  /// network. A deck is only rewritten when **every** one of its commanders
  /// resolves to exactly one cached card. A name held by two cached printings
  /// is left alone rather than guessed at, and so is a name the cache has
  /// never seen: attaching the wrong card is worse than attaching none, since
  /// commander damage is tracked per card.
  ///
  /// Returns how many decks were reconnected. Safe to run more than once —
  /// a deck with ids is never considered.
  Future<int> relinkLegacyCommanders() async {
    final stale =
        await (select(decks)..where(
              (d) =>
                  d.commanderIds.equals('') & d.commanderName.equals('').not(),
            ))
            .get();

    var relinked = 0;
    for (final deck in stale) {
      // Partners were stored joined, exactly as they were displayed.
      final names = [
        for (final part in deck.commanderName.split(' + '))
          if (part.trim().isNotEmpty) part.trim(),
      ];
      if (names.isEmpty) continue;

      final ids = <String>[];
      for (final name in names) {
        final matches = await (select(
          cachedCards,
        )..where((c) => c.name.equals(name))).get();
        if (matches.length != 1) break;
        ids.add(matches.single.id);
      }
      if (ids.length != names.length) continue;

      await (update(decks)..where((d) => d.id.equals(deck.id))).write(
        DecksCompanion(commanderIds: Value(ids.join(','))),
      );
      relinked++;
    }
    return relinked;
  }

  /// Turns each old single deck profile into that player's first deck.
  ///
  /// Reads with raw SQL because `deck_profiles` no longer exists in the Dart
  /// schema — it is dropped at the end of this step.
  Future<void> _migrateDeckProfilesToDecks(Migrator m) async {
    // Installs older than v3 never had the table at all, so there is nothing
    // to carry over and nothing to drop.
    final present = await customSelect(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name = 'deck_profiles'",
    ).get();
    if (present.isEmpty) return;

    final now = DateTime.now();
    final legacy = await customSelect(
      'SELECT player_id, commander_name, color_identity, power, archetypes, '
      'interaction FROM deck_profiles',
    ).get();

    for (final row in legacy) {
      await into(decks).insert(
        DeckRow(
          // Derived from the player id so the backfill below can find it
          // without reading these rows back.
          id: 'legacy-${row.read<String>('player_id')}',
          playerId: row.read<String>('player_id'),
          name: '',
          commanderName: row.read<String>('commander_name'),
          commanderIds: '',
          colorIdentity: row.read<String>('color_identity'),
          power: row.read<int>('power'),
          archetypes: row.read<String>('archetypes'),
          interaction: row.read<String>('interaction'),
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    // Until now the app knew of exactly one deck per player, so as far as it
    // is concerned every game in history was played with it. Attributing that
    // history to the migrated deck keeps each self-correcting power rating
    // where it already was; leaving it unattributed would silently reset
    // everyone to their hand-entered number.
    await customStatement(
      "UPDATE game_participants SET deck_id = 'legacy-' || profile_id "
      'WHERE deck_id IS NULL AND profile_id IN '
      '(SELECT player_id FROM deck_profiles)',
    );

    await m.deleteTable('deck_profiles');
  }

  // ---- Settings -----------------------------------------------------------

  Future<Map<String, String>> allSettings() async {
    final rows = await select(settings).get();
    return {for (final row in rows) row.key: row.value};
  }

  Future<void> putSetting(String key, String value) =>
      into(settings).insertOnConflictUpdate(SettingRow(key: key, value: value));

  // ---- Decks and pod-building history -------------------------------------

  /// Every deck, most recently played first so a player's current deck leads.
  Future<List<DeckRow>> allDecks() {
    return (select(decks)..orderBy([
          (t) =>
              OrderingTerm(expression: t.lastPlayedAt, mode: OrderingMode.desc),
          (t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc),
        ]))
        .get();
  }

  Future<void> upsertDeck(DeckRow deck) =>
      into(decks).insertOnConflictUpdate(deck);

  /// Removes a deck but leaves its games alone.
  ///
  /// The participant rows keep pointing at an id that no longer resolves,
  /// which is deliberate: a game that was played still happened, and rewriting
  /// history to erase the deck would alter everyone else's record too.
  Future<void> deleteDeck(String id) =>
      (delete(decks)..where((t) => t.id.equals(id))).go();

  Future<void> touchDecks(List<String> ids, DateTime when) async {
    await batch((b) {
      for (final id in ids) {
        b.update(
          decks,
          DecksCompanion(lastPlayedAt: Value(when)),
          where: (t) => t.id.equals(id),
        );
      }
    });
  }

  /// Games played and won per *deck*, for per-deck records and the
  /// self-correcting power rating.
  Future<Map<String, ({int games, int wins})>> deckRecords() async {
    final rows = await select(gameParticipants).get();
    // Roulette nights are recorded in full but never counted here, so being
    // handed somebody's deck cannot move their power rating.
    final roulette = {
      for (final game in await (select(
        games,
      )..where((t) => t.deckRoulette)).get())
        game.id,
    };

    final records = <String, ({int games, int wins})>{};
    for (final row in rows) {
      final deckId = row.deckId;
      if (deckId == null || roulette.contains(row.gameId)) continue;
      final current = records[deckId] ?? (games: 0, wins: 0);
      records[deckId] = (
        games: current.games + 1,
        wins: current.wins + (row.position == 1 ? 1 : 0),
      );
    }
    return records;
  }

  /// How many finished games each pair of players has shared.
  ///
  /// Drives "Fresh Matchups": a pair that keeps being drawn together should be
  /// separated. Computed on demand rather than maintained incrementally — a
  /// playgroup's history is small and this runs once per pod build.
  Future<Map<String, int>> matchupCounts({int lastGames = 20}) async {
    final recent = await recentGames(limit: lastGames);
    final counts = <String, int>{};

    for (final game in recent) {
      final ids = (await participantsOf(game.id))
          .map((p) => p.profileId)
          .toList();
      for (var i = 0; i < ids.length; i++) {
        for (var j = i + 1; j < ids.length; j++) {
          final key = ids[i].compareTo(ids[j]) <= 0
              ? '${ids[i]}|${ids[j]}'
              : '${ids[j]}|${ids[i]}';
          counts[key] = (counts[key] ?? 0) + 1;
        }
      }
    }
    return counts;
  }

  /// Full per-player statistics across all saved games.
  ///
  /// Walks the games once and accumulates, rather than issuing a query per
  /// player — a playgroup's history is small and this keeps it to two reads.
  Future<Map<String, PlayerStatsAccumulator>> playerStatistics() async {
    final finished = await recentGames(limit: 1000);
    final byGame = {for (final g in finished) g.id: g};
    final rows = await select(gameParticipants).get();

    final stats = <String, PlayerStatsAccumulator>{};
    final rosters = <String, List<String>>{};

    for (final row in rows) {
      final game = byGame[row.gameId];
      // Unfinished games are excluded: a game in progress has no result.
      if (game?.finishedAt == null) continue;

      final acc = stats.putIfAbsent(
        row.profileId,
        () => PlayerStatsAccumulator(row.profileId, row.name),
      );
      acc.name = row.name;
      acc.games++;
      if (row.position == 1) acc.wins++;
      acc.totalPosition += row.position ?? 0;
      acc.totalDuration += game!.finishedAt!.difference(game.startedAt);

      rosters.putIfAbsent(row.gameId, () => []).add(row.profileId);
    }

    // Second pass for who played against whom.
    for (final roster in rosters.values) {
      for (final id in roster) {
        final acc = stats[id];
        if (acc == null) continue;
        for (final other in roster) {
          if (other == id) continue;
          acc.opponents[other] = (acc.opponents[other] ?? 0) + 1;
        }
      }
    }

    return stats;
  }

  /// Games played and won per player, across all saved history.
  Future<Map<String, ({int games, int wins})>> playerRecords() async {
    final rows = await select(gameParticipants).get();
    final records = <String, ({int games, int wins})>{};
    for (final row in rows) {
      final current = records[row.profileId] ?? (games: 0, wins: 0);
      records[row.profileId] = (
        games: current.games + 1,
        wins: current.wins + (row.position == 1 ? 1 : 0),
      );
    }
    return records;
  }

  // ---- Offline card cache -------------------------------------------------

  Future<void> cacheCards(Iterable<CachedCardsCompanion> cards) async {
    await batch((b) {
      for (final card in cards) {
        // Upsert: refreshing a card must not reset its use count.
        b.insert(cachedCards, card, mode: InsertMode.insertOrReplace);
      }
    });
  }

  /// Offline substitute for a Scryfall search.
  ///
  /// Ranked by how often the group has actually picked the card, then by name,
  /// so a playgroup's regular commanders surface first without a network call.
  Future<List<CachedCardRow>> searchCachedCards(
    String query, {
    int limit = 30,
  }) {
    final needle = '%${query.trim().toLowerCase()}%';
    return (select(cachedCards)
          ..where((t) => t.searchName.like(needle))
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.useCount, mode: OrderingMode.desc),
            (t) => OrderingTerm(expression: t.name),
          ])
          ..limit(limit))
        .get();
  }

  /// Looks up specific cached cards, for rehydrating a saved deck's command
  /// zone without a network call.
  Future<List<CachedCardRow>> cachedCardsByIds(List<String> ids) {
    if (ids.isEmpty) return Future.value(const []);
    return (select(cachedCards)..where((t) => t.id.isIn(ids))).get();
  }

  Future<void> recordCardUse(String cardId) {
    return customUpdate(
      'UPDATE cached_cards SET use_count = use_count + 1 WHERE id = ?',
      variables: [Variable.withString(cardId)],
      updates: {cachedCards},
    );
  }

  Future<int> cachedCardCount() async {
    final row = await (selectOnly(
      cachedCards,
    )..addColumns([cachedCards.id.count()])).getSingle();
    return row.read(cachedCards.id.count()) ?? 0;
  }

  Future<List<PlayerProfileRow>> allProfiles() {
    return (select(playerProfiles)..orderBy([
          // Most recently played first, so the regulars surface at the top.
          (t) =>
              OrderingTerm(expression: t.lastPlayedAt, mode: OrderingMode.desc),
          (t) => OrderingTerm(expression: t.name),
        ]))
        .get();
  }

  Future<void> upsertProfile(PlayerProfileRow profile) {
    return into(playerProfiles).insertOnConflictUpdate(profile);
  }

  /// Renames a player everywhere they appear.
  ///
  /// Participant rows carry a copy of the name, which is what keeps history
  /// readable for a player who has since been deleted. That copy has to be
  /// updated too: leaving it behind would show the old name in history and in
  /// everyone else's "plays against" list, so one person would read as two.
  Future<void> renameProfile(String id, String name) {
    return transaction(() async {
      await (update(playerProfiles)..where((t) => t.id.equals(id))).write(
        PlayerProfilesCompanion(name: Value(name)),
      );
      await (update(gameParticipants)..where((t) => t.profileId.equals(id)))
          .write(GameParticipantsCompanion(name: Value(name)));
    });
  }

  /// Removes a player and the decks they owned.
  ///
  /// Their games are deliberately left alone. A game that was played still
  /// happened, and deleting its rows would change everyone else's record for
  /// that night — the participant rows carry their own copy of the name, so
  /// history stays readable without them.
  Future<void> deleteProfile(String id) {
    return transaction(() async {
      // Without this the deck rows linger forever, hidden but never collected.
      await (delete(decks)..where((t) => t.playerId.equals(id))).go();
      await (delete(playerProfiles)..where((t) => t.id.equals(id))).go();
    });
  }

  Future<void> touchProfiles(List<String> ids, DateTime when) async {
    await batch((b) {
      for (final id in ids) {
        b.update(
          playerProfiles,
          PlayerProfilesCompanion(lastPlayedAt: Value(when)),
          where: (t) => t.id.equals(id),
        );
      }
    });
  }

  /// Persists a finished game and its participants in one transaction, so
  /// history can never contain a game with no players.
  Future<void> saveFinishedGame({
    required GameRow game,
    required List<GameParticipantsCompanion> participants,
  }) {
    return transaction(() async {
      await into(games).insertOnConflictUpdate(game);
      for (final participant in participants) {
        await into(gameParticipants).insert(participant);
      }
      await touchProfiles(
        participants.map((p) => p.profileId.value).toList(),
        game.finishedAt ?? DateTime.now(),
      );
    });
  }

  /// Writes a game that was played on somebody else's phone.
  ///
  /// Returns false if this game is already in history, in which case nothing
  /// is written. The check has to happen inside the transaction rather than
  /// before it: [saveFinishedGame] upserts the game but plain-inserts its
  /// participants against an autoincrementing key, so importing the same
  /// result twice would otherwise leave one game with two sets of
  /// participants — silently doubling those players' and decks' games and
  /// wins, with nothing on screen to show for it.
  Future<bool> importFinishedGame({
    required GameRow game,
    required List<GameParticipantsCompanion> participants,
  }) {
    return transaction(() async {
      final existing = await (select(
        games,
      )..where((t) => t.id.equals(game.id))).getSingleOrNull();
      if (existing != null) return false;

      await into(games).insert(game);
      for (final participant in participants) {
        await into(gameParticipants).insert(participant);
      }

      // These people really did play tonight, just at the next table along, so
      // they should surface as recently active exactly as if they hadn't.
      // Updates for ids this phone doesn't know are harmless no-ops.
      final when = game.finishedAt ?? DateTime.now();
      await touchProfiles(
        participants.map((p) => p.profileId.value).toList(),
        when,
      );
      await touchDecks([for (final p in participants) ?p.deckId.value], when);

      return true;
    });
  }

  Future<List<GameRow>> recentGames({int limit = 50}) {
    return (select(games)
          ..where((t) => t.finishedAt.isNotNull())
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.finishedAt, mode: OrderingMode.desc),
          ])
          ..limit(limit))
        .get();
  }

  Future<List<GameParticipantRow>> participantsOf(String gameId) {
    return (select(gameParticipants)
          ..where((t) => t.gameId.equals(gameId))
          ..orderBy([(t) => OrderingTerm(expression: t.seatIndex)]))
        .get();
  }

  /// The seat list from the most recently finished game, for "Last Pod".
  Future<List<GameParticipantRow>> lastPodParticipants() async {
    final recent = await recentGames(limit: 1);
    if (recent.isEmpty) return const [];
    return participantsOf(recent.first.id);
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'podwise.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}

/// Mutable tally used while walking saved games, converted to an immutable
/// [PlayerStats] once complete.
class PlayerStatsAccumulator {
  PlayerStatsAccumulator(this.profileId, this.name);

  final String profileId;
  String name;
  int games = 0;
  int wins = 0;
  int totalPosition = 0;
  Duration totalDuration = Duration.zero;
  final Map<String, int> opponents = {};
}

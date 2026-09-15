import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podwise/data/database.dart';
import 'package:podwise/domain/pod.dart';
import 'package:sqlite3/sqlite3.dart';

/// A player owning several decks is the whole point of this feature, so the
/// tests cover both halves of it: that results land on the right deck, and
/// that the upgrade from one-deck-per-player does not lose anybody's ratings.
void main() {
  group('DeckProfile naming', () {
    const base = DeckProfile(playerId: 'p', playerName: 'Dave');

    test('a nickname wins over the commander', () {
      expect(
        base
            .copyWith(deckName: 'Stax pile', commanderName: 'Winter Orb Guy')
            .displayName,
        'Stax pile',
      );
    });

    test('without a nickname the commander names the deck', () {
      expect(base.copyWith(commanderName: 'Atraxa').displayName, 'Atraxa');
    });

    test('a deck with neither still has something to call it', () {
      expect(base.displayName, 'Untitled deck');
    });

    test('an untouched deck is not treated as rated', () {
      // Power 5 with no archetypes is the default, which means nobody has
      // said anything about this deck yet.
      expect(base.isRated, isFalse);
      expect(base.copyWith(power: 6).isRated, isTrue);
      expect(base.copyWith(archetypes: {DeckArchetype.stax}).isRated, isTrue);
    });
  });

  group('per-deck power correction', () {
    const deck = DeckProfile(playerId: 'p', playerName: 'Dave', power: 6);

    test('a deck with its own winning record plays above its rating', () {
      final winning = DeckProfile(
        playerId: deck.playerId,
        playerName: deck.playerName,
        power: 6,
        gamesPlayed: 8,
        wins: 6,
      );
      expect(winning.effectivePower, greaterThan(6));
    });

    test('two decks owned by one player correct independently', () {
      const shared = (playerId: 'p', playerName: 'Dave');
      final strong = DeckProfile(
        playerId: shared.playerId,
        playerName: shared.playerName,
        deckId: 'a',
        power: 6,
        gamesPlayed: 8,
        wins: 6,
      );
      final weak = DeckProfile(
        playerId: shared.playerId,
        playerName: shared.playerName,
        deckId: 'b',
        power: 6,
        gamesPlayed: 8,
        wins: 0,
      );
      // The player's overall win rate is 37.5%, but neither deck is average —
      // averaging them would misrepresent both.
      expect(strong.effectivePower, greaterThan(weak.effectivePower + 1));
    });
  });

  group('deck records', () {
    late PodWiseDatabase db;

    setUp(() => db = PodWiseDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<void> addGame(
      String gameId,
      List<({String deckId, int position})> entries,
    ) async {
      await db.saveFinishedGame(
        game: GameRow(
          id: gameId,
          startedAt: DateTime(2026),
          finishedAt: DateTime(2026, 1, 1, 1),
          startingLife: 40,
          deckRoulette: false,
        ),
        participants: [
          for (var i = 0; i < entries.length; i++)
            GameParticipantsCompanion.insert(
              gameId: gameId,
              profileId: 'dave',
              name: 'Dave',
              seatIndex: i,
              colorIndex: i,
              finalLife: 0,
              deckId: Value(entries[i].deckId),
              position: Value(entries[i].position),
            ),
        ],
      );
    }

    test('results are counted against the deck that played them', () async {
      await addGame('g1', [
        (deckId: 'atraxa', position: 1),
        (deckId: 'precon', position: 2),
      ]);
      await addGame('g2', [
        (deckId: 'atraxa', position: 1),
        (deckId: 'precon', position: 3),
      ]);

      final records = await db.deckRecords();
      expect(records['atraxa'], (games: 2, wins: 2));
      expect(records['precon'], (games: 2, wins: 0));
    });

    test('games played without a deck are left unattributed', () async {
      await db.saveFinishedGame(
        game: GameRow(
          id: 'g3',
          startedAt: DateTime(2026),
          finishedAt: DateTime(2026, 1, 1, 1),
          startingLife: 40,
          deckRoulette: false,
        ),
        participants: [
          GameParticipantsCompanion.insert(
            gameId: 'g3',
            profileId: 'dave',
            name: 'Dave',
            seatIndex: 0,
            colorIndex: 0,
            finalLife: 40,
            position: const Value(1),
          ),
        ],
      );

      // Counting these against some arbitrary deck would inflate its rating
      // for a game it never played.
      expect(await db.deckRecords(), isEmpty);
    });

    test('deleting a deck leaves its games in history', () async {
      await db.upsertDeck(
        DeckRow(
          id: 'atraxa',
          playerId: 'dave',
          name: '',
          commanderName: 'Atraxa',
          commanderIds: '',
          colorIdentity: 'WUBG',
          power: 7,
          archetypes: '',
          interaction: '',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
      await addGame('g4', [(deckId: 'atraxa', position: 1)]);

      await db.deleteDeck('atraxa');

      expect(await db.allDecks(), isEmpty);
      expect((await db.participantsOf('g4')).single.deckId, 'atraxa');
    });
  });

  group('upgrade from one deck per player', () {
    late Database raw;
    late PodWiseDatabase db;

    setUp(() {
      raw = sqlite3.openInMemory();
      _createVersion5Schema(raw);
      db = PodWiseDatabase.forTesting(NativeDatabase.opened(raw));
    });

    tearDown(() => db.close());

    test('each old profile becomes that player\'s first deck', () async {
      final decks = await db.allDecks();

      expect(decks, hasLength(2));
      final dave = decks.firstWhere((d) => d.playerId == 'dave');
      expect(dave.commanderName, 'Atraxa, Praetors\' Voice');
      expect(dave.power, 7);
      expect(dave.archetypes, 'superfriends');
      expect(dave.colorIdentity, 'WUBG');
    });

    test('existing games stay attached to the migrated deck', () async {
      // The whole point: a rating that had corrected itself over six games
      // must not silently snap back to the hand-entered number.
      final records = await db.deckRecords();
      expect(records['legacy-dave'], (games: 2, wins: 1));
      expect(records['legacy-ben'], (games: 2, wins: 1));
    });

    test('player-level statistics are unchanged by the upgrade', () async {
      final stats = await db.playerStatistics();
      expect(stats['dave']!.games, 2);
      expect(stats['dave']!.wins, 1);
    });

    test('the old table is gone afterwards', () async {
      // Forces the migration to have run before the table is looked for.
      await db.allDecks();
      final tables = raw.select(
        "SELECT name FROM sqlite_master WHERE name = 'deck_profiles'",
      );
      expect(tables, isEmpty);
    });
  });
}

/// Builds the database exactly as schema v5 left it, so the v6 migration runs
/// against the shape a real install actually has.
void _createVersion5Schema(Database raw) {
  raw.execute('''
    CREATE TABLE player_profiles (
      id TEXT NOT NULL PRIMARY KEY,
      name TEXT NOT NULL,
      color_index INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL,
      last_played_at INTEGER
    );
  ''');
  raw.execute('''
    CREATE TABLE games (
      id TEXT NOT NULL PRIMARY KEY,
      started_at INTEGER NOT NULL,
      finished_at INTEGER,
      starting_life INTEGER NOT NULL,
      winner_profile_id TEXT
    );
  ''');
  raw.execute('''
    CREATE TABLE game_participants (
      row_id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      game_id TEXT NOT NULL REFERENCES games (id),
      profile_id TEXT NOT NULL,
      name TEXT NOT NULL,
      seat_index INTEGER NOT NULL,
      color_index INTEGER NOT NULL,
      final_life INTEGER NOT NULL,
      position INTEGER,
      eliminated INTEGER NOT NULL DEFAULT 0
    );
  ''');
  raw.execute('''
    CREATE TABLE cached_cards (
      id TEXT NOT NULL PRIMARY KEY,
      name TEXT NOT NULL,
      search_name TEXT NOT NULL,
      type_line TEXT NOT NULL,
      color_identity TEXT NOT NULL DEFAULT '',
      oracle_text TEXT,
      mana_cost TEXT,
      image_small TEXT,
      image_normal TEXT,
      image_art_crop TEXT,
      scryfall_uri TEXT,
      cached_at INTEGER NOT NULL,
      use_count INTEGER NOT NULL DEFAULT 0,
      commander_legal INTEGER NOT NULL DEFAULT 1
    );
  ''');
  raw.execute('''
    CREATE TABLE deck_profiles (
      player_id TEXT NOT NULL PRIMARY KEY,
      commander_name TEXT NOT NULL DEFAULT '',
      color_identity TEXT NOT NULL DEFAULT '',
      power INTEGER NOT NULL DEFAULT 5,
      archetypes TEXT NOT NULL DEFAULT '',
      interaction TEXT NOT NULL DEFAULT '',
      updated_at INTEGER NOT NULL
    );
  ''');
  raw.execute('''
    CREATE TABLE settings (
      key TEXT NOT NULL PRIMARY KEY,
      value TEXT NOT NULL
    );
  ''');

  const started = 1780000000;
  raw.execute(
    'INSERT INTO player_profiles (id, name, color_index, created_at) '
    "VALUES ('dave', 'Dave', 0, $started), ('ben', 'Ben', 1, $started)",
  );
  raw.execute(
    'INSERT INTO deck_profiles '
    '(player_id, commander_name, color_identity, power, archetypes, '
    'interaction, updated_at) VALUES '
    "('dave', 'Atraxa, Praetors'' Voice', 'WUBG', 7, 'superfriends', "
    "'creatureRemoval', $started), "
    "('ben', 'Krenko, Mob Boss', 'R', 4, 'tokens', '', $started)",
  );

  for (var i = 1; i <= 2; i++) {
    raw.execute(
      'INSERT INTO games (id, started_at, finished_at, starting_life, '
      "winner_profile_id) VALUES ('g$i', $started, ${started + 3600}, 40, "
      "'${i == 1 ? 'dave' : 'ben'}')",
    );
    raw.execute(
      'INSERT INTO game_participants '
      '(game_id, profile_id, name, seat_index, color_index, final_life, '
      'position, eliminated) VALUES '
      "('g$i', 'dave', 'Dave', 0, 0, 0, ${i == 1 ? 1 : 2}, 0), "
      "('g$i', 'ben', 'Ben', 1, 1, 0, ${i == 1 ? 2 : 1}, 0)",
    );
  }

  raw.execute('PRAGMA user_version = 5');
}

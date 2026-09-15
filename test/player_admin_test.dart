import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podwise/data/database.dart';
import 'package:podwise/state/providers.dart';

/// Renaming and removing a player both reach further than they look: the name
/// is copied into every game they played, and their decks hang off them.
void main() {
  late PodWiseDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = PodWiseDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );

    await db.upsertProfile(
      PlayerProfileRow(
        id: 'dave',
        name: 'Dave',
        colorIndex: 1,
        createdAt: DateTime(2026),
      ),
    );
    await db.upsertProfile(
      PlayerProfileRow(
        id: 'ben',
        name: 'Ben',
        colorIndex: 2,
        createdAt: DateTime(2026),
      ),
    );
    await db.upsertDeck(
      DeckRow(
        id: 'atraxa',
        playerId: 'dave',
        name: '',
        commanderName: 'Atraxa',
        commanderIds: '',
        colorIdentity: 'WUBG',
        power: 8,
        archetypes: '',
        interaction: '',
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    await db.saveFinishedGame(
      game: GameRow(
        id: 'g1',
        startedAt: DateTime(2026, 9, 13, 19),
        finishedAt: DateTime(2026, 9, 13, 20),
        startingLife: 40,
        deckRoulette: false,
        winnerProfileId: 'dave',
      ),
      participants: const [],
    );
    await db
        .into(db.gameParticipants)
        .insert(
          GameParticipantsCompanion.insert(
            gameId: 'g1',
            profileId: 'dave',
            name: 'Dave',
            seatIndex: 0,
            colorIndex: 1,
            finalLife: 12,
            deckId: const Value('atraxa'),
            position: const Value(1),
          ),
        );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> reloadProfiles() =>
      container.read(playerProfilesProvider.future);

  group('renaming', () {
    test('updates the name in past games too', () async {
      await reloadProfiles();
      final dave = (await container.read(playerProfilesProvider.future))
          .firstWhere((p) => p.id == 'dave');

      await container
          .read(playerProfilesProvider.notifier)
          .rename(dave, 'David');

      expect(
        (await db.allProfiles()).firstWhere((p) => p.id == 'dave').name,
        'David',
      );
      // Left behind, the old name would show in history and in everyone
      // else's "plays against" list, so one person would read as two.
      expect((await db.participantsOf('g1')).single.name, 'David');
    });

    test('does not disturb the creation date', () async {
      await reloadProfiles();
      final dave = (await container.read(playerProfilesProvider.future))
          .firstWhere((p) => p.id == 'dave');

      await container
          .read(playerProfilesProvider.notifier)
          .rename(dave, 'David');

      expect(
        (await db.allProfiles()).firstWhere((p) => p.id == 'dave').createdAt,
        DateTime(2026),
      );
    });
  });

  group('removing', () {
    test('takes their decks with them', () async {
      await db.deleteProfile('dave');

      // Otherwise the deck rows linger forever, hidden but never collected.
      expect(await db.allDecks(), isEmpty);
      expect((await db.allProfiles()).map((p) => p.id), ['ben']);
    });

    test('leaves the games they played alone', () async {
      await db.deleteProfile('dave');

      // A game that was played still happened; deleting its rows would change
      // everyone else's record for that night.
      expect(await db.recentGames(), hasLength(1));
      final participants = await db.participantsOf('g1');
      expect(participants.single.name, 'Dave');
      expect(participants.single.deckId, 'atraxa');
      // Their record survives them, which is what keeps history readable.
      expect((await db.playerStatistics())['dave']!.wins, 1);
    });

    test('does not touch anybody else', () async {
      await db.upsertDeck(
        DeckRow(
          id: 'krenko',
          playerId: 'ben',
          name: '',
          commanderName: 'Krenko',
          commanderIds: '',
          colorIdentity: 'R',
          power: 5,
          archetypes: '',
          interaction: '',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );

      await db.deleteProfile('dave');

      expect((await db.allDecks()).map((d) => d.id), ['krenko']);
    });
  });
}

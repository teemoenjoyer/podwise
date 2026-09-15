import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podwise/data/database.dart';
import 'package:podwise/domain/commander.dart';
import 'package:podwise/domain/models.dart';

/// Decks carried over from before card ids existed know their commander's
/// name and nothing else, so they showed a commander everywhere a name was
/// enough and none where the card was needed — no art on the GAME OVER
/// screen, and commander damage tracked against a stand-in.
///
/// This is the first migration that rewrites existing rows rather than adding
/// to them, so most of what is worth testing is what it refuses to touch.
void main() {
  late PodWiseDatabase db;

  setUp(() => db = PodWiseDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> cache(String id, String name) => db.cacheCards([
    CachedCardsCompanion.insert(
      id: id,
      name: name,
      searchName: name.toLowerCase(),
      typeLine: 'Legendary Creature',
      cachedAt: DateTime(2026),
    ),
  ]);

  Future<void> addDeck({
    required String id,
    required String commanderName,
    String commanderIds = '',
  }) => db.upsertDeck(
    DeckRow(
      id: id,
      playerId: 'jordan',
      name: '',
      commanderName: commanderName,
      commanderIds: commanderIds,
      colorIdentity: '',
      power: 5,
      archetypes: '',
      interaction: '',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  );

  Future<String> idsOf(String deckId) async =>
      (await db.allDecks()).firstWhere((d) => d.id == deckId).commanderIds;

  test('a named commander is reconnected to its cached card', () async {
    await cache('shao-jun-id', 'Shao Jun');
    await addDeck(id: 'legacy', commanderName: 'Shao Jun');

    expect(await db.relinkLegacyCommanders(), 1);
    expect(await idsOf('legacy'), 'shao-jun-id');
  });

  test('partners stored as one joined name are split apart', () async {
    await cache('joel-id', 'Joel, Resolute Survivor');
    await cache('ellie-id', 'Ellie, Vengeful Hunter');
    await addDeck(
      id: 'legacy',
      commanderName: 'Joel, Resolute Survivor + Ellie, Vengeful Hunter',
    );

    expect(await db.relinkLegacyCommanders(), 1);
    // In the order they were stored, so the primary commander stays primary —
    // that is the card whose art represents the deck.
    expect(await idsOf('legacy'), 'joel-id,ellie-id');
  });

  test('a partner pair is left alone unless both halves resolve', () async {
    await cache('joel-id', 'Joel, Resolute Survivor');
    await addDeck(
      id: 'legacy',
      commanderName: 'Joel, Resolute Survivor + Ellie, Vengeful Hunter',
    );

    // Half a command zone would quietly lose one commander's damage tracking,
    // which is worse than the deck staying as it was.
    expect(await db.relinkLegacyCommanders(), 0);
    expect(await idsOf('legacy'), '');
  });

  test('a name held by two cached printings is not guessed at', () async {
    await cache('printing-a', 'Captain Lannery Storm');
    await cache('printing-b', 'Captain Lannery Storm');
    await addDeck(id: 'legacy', commanderName: 'Captain Lannery Storm');

    expect(await db.relinkLegacyCommanders(), 0);
    expect(await idsOf('legacy'), '');
  });

  test('a commander the cache has never seen is left alone', () async {
    await addDeck(id: 'legacy', commanderName: 'Some Uncached Commander');

    // No network in a migration, and no guessing.
    expect(await db.relinkLegacyCommanders(), 0);
    expect(await idsOf('legacy'), '');
  });

  test('a deck that already has ids is never rewritten', () async {
    await cache('other-id', 'Krenko, Mob Boss');
    await addDeck(
      id: 'modern',
      commanderName: 'Krenko, Mob Boss',
      commanderIds: 'the-printing-they-chose',
    );

    expect(await db.relinkLegacyCommanders(), 0);
    expect(await idsOf('modern'), 'the-printing-they-chose');
  });

  test('running it twice changes nothing the second time', () async {
    await cache('shao-jun-id', 'Shao Jun');
    await addDeck(id: 'legacy', commanderName: 'Shao Jun');

    expect(await db.relinkLegacyCommanders(), 1);
    expect(await db.relinkLegacyCommanders(), 0);
    expect(await idsOf('legacy'), 'shao-jun-id');
  });

  test('a deck with no commander at all is skipped', () async {
    await addDeck(id: 'nameless', commanderName: '');

    expect(await db.relinkLegacyCommanders(), 0);
  });

  test('the reconnected deck rebuilds a real command zone', () async {
    await cache('shao-jun-id', 'Shao Jun');
    await addDeck(id: 'legacy', commanderName: 'Shao Jun');
    await db.relinkLegacyCommanders();

    // The point of the whole exercise: cards, not a name. Everything that was
    // missing — art, and per-commander damage — hangs off this.
    final ids = (await idsOf('legacy')).split(',');
    final rows = await db.cachedCardsByIds(ids);
    expect(rows.single.name, 'Shao Jun');
  });

  group('naming a commander the app has no card for', () {
    const seat = Seat(
      profileId: 'jordan',
      name: 'Jordan',
      colorIndex: 0,
      life: 40,
      commanderLabel: 'Shao Jun',
    );

    test('the label names the command zone', () {
      expect(seat.commanderDisplayName, 'Shao Jun');
    });

    test('the damage source is named after the deck, not the player', () {
      // It used to read "Jordan's commander", which tells the table nothing
      // it did not already know.
      expect(seat.damageSources.single.name, 'Shao Jun');
    });

    test('real cards win over the label', () {
      const withCards = Seat(
        profileId: 'jordan',
        name: 'Jordan',
        colorIndex: 0,
        life: 40,
        commanderLabel: 'Something Stale',
        commanders: CommanderSet(
          cards: [
            MagicCard(
              id: 'shao-jun-id',
              name: 'Shao Jun',
              typeLine: '',
              colorIdentity: {},
            ),
          ],
        ),
      );

      expect(withCards.commanderDisplayName, 'Shao Jun');
      expect(withCards.damageSources.single.id, 'shao-jun-id');
    });

    test('a seat with nothing naming its commander still deals damage', () {
      const bare = Seat(
        profileId: 'dave',
        name: 'Dave',
        colorIndex: 0,
        life: 40,
      );

      // `isNull` is ambiguous here — drift exports one too.
      expect(bare.commanderDisplayName, null);
      expect(bare.damageSources.single.name, "Dave's commander");
    });

    test('the label survives a life change', () {
      // copyWith rebuilds the whole seat, so anything it forgets to carry is
      // silently lost the first time somebody takes damage.
      expect(seat.copyWith(life: 33).commanderDisplayName, 'Shao Jun');
    });
  });
}

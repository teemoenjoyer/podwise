import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podwise/data/database.dart';
import 'package:podwise/domain/commander.dart';
import 'package:podwise/domain/models.dart';
import 'package:podwise/state/providers.dart';

/// The brief's own worked example, in section 11:
///
///   Sarah's Atraxa deals 5, 3 and 4 to Bob  -> Bob has 12/21 from Atraxa
///   Sarah then attacks Chris for 6          -> Chris has 6/21
///   Bob's total must remain 12
void main() {
  late PodWiseDatabase db;
  late ProviderContainer container;

  const atraxa = MagicCard(
    id: 'atraxa',
    name: "Atraxa, Praetors' Voice",
    typeLine: 'Legendary Creature',
    colorIdentity: {},
  );
  const tymna = MagicCard(
    id: 'tymna',
    name: 'Tymna the Weaver',
    typeLine: 'Legendary Creature',
    colorIdentity: {},
    oracleText: 'Partner',
  );
  const thrasios = MagicCard(
    id: 'thrasios',
    name: 'Thrasios, Triton Hero',
    typeLine: 'Legendary Creature',
    colorIdentity: {},
    oracleText: 'Partner',
  );

  setUp(() {
    db = PodWiseDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  ActiveGameNotifier startGame({
    Map<String, CommanderSet> commanders = const {},
  }) {
    final notifier = container.read(activeGameProvider.notifier);
    notifier.start(
      startingLife: 40,
      players: const [
        PlayerProfile(id: 'sarah', name: 'Sarah'),
        PlayerProfile(id: 'bob', name: 'Bob'),
        PlayerProfile(id: 'chris', name: 'Chris'),
        PlayerProfile(id: 'dave', name: 'Dave'),
      ],
      commanders: commanders,
    );
    return notifier;
  }

  GameState game() => container.read(activeGameProvider)!;

  int lifeOf(String id) =>
      game().seats.firstWhere((s) => s.profileId == id).life;

  group("the brief's worked example", () {
    test('accumulates damage from one commander to one player', () {
      final notifier = startGame();

      for (final hit in [5, 3, 4]) {
        notifier.adjustCommanderDamage(
          sourceCardId: atraxa.id,
          targetProfileId: 'bob',
          delta: hit,
        );
      }

      expect(game().damageFrom(atraxa.id, 'bob'), 12);
    });

    test('damage to a second player is tracked separately', () {
      final notifier = startGame();

      notifier.adjustCommanderDamage(
        sourceCardId: atraxa.id,
        targetProfileId: 'bob',
        delta: 12,
      );
      notifier.adjustCommanderDamage(
        sourceCardId: atraxa.id,
        targetProfileId: 'chris',
        delta: 6,
      );

      expect(game().damageFrom(atraxa.id, 'chris'), 6);
      // The critical assertion: Chris taking damage must not touch Bob.
      expect(game().damageFrom(atraxa.id, 'bob'), 12);
    });

    test('two partners deal damage independently', () {
      final notifier = startGame(
        commanders: {
          'sarah': const CommanderSet(
            cards: [tymna, thrasios],
            pairing: CommanderPairing.partner,
          ),
        },
      );

      notifier.adjustCommanderDamage(
        sourceCardId: tymna.id,
        targetProfileId: 'bob',
        delta: 8,
      );
      notifier.adjustCommanderDamage(
        sourceCardId: thrasios.id,
        targetProfileId: 'bob',
        delta: 9,
      );

      // 17 total damage, but neither commander is near the 21 threshold.
      expect(game().damageFrom(tymna.id, 'bob'), 8);
      expect(game().damageFrom(thrasios.id, 'bob'), 9);
      expect(game().isLethalCommanderDamage('bob'), isFalse);
    });
  });

  group('life interaction', () {
    test('commander damage also reduces life', () {
      final notifier = startGame();

      notifier.adjustCommanderDamage(
        sourceCardId: atraxa.id,
        targetProfileId: 'bob',
        delta: 7,
      );

      expect(lifeOf('bob'), 33);
      // Only the target loses life.
      expect(lifeOf('chris'), 40);
      expect(lifeOf('sarah'), 40);
    });

    test('reducing recorded damage gives the life back', () {
      final notifier = startGame();

      notifier.adjustCommanderDamage(
        sourceCardId: atraxa.id,
        targetProfileId: 'bob',
        delta: 7,
      );
      notifier.adjustCommanderDamage(
        sourceCardId: atraxa.id,
        targetProfileId: 'bob',
        delta: -3,
      );

      expect(game().damageFrom(atraxa.id, 'bob'), 4);
      expect(lifeOf('bob'), 36);
    });

    test(
      'damage never goes negative, and life is not inflated by over-tapping',
      () {
        final notifier = startGame();

        notifier.adjustCommanderDamage(
          sourceCardId: atraxa.id,
          targetProfileId: 'bob',
          delta: 2,
        );
        // Over-correct by more than was ever dealt.
        notifier.adjustCommanderDamage(
          sourceCardId: atraxa.id,
          targetProfileId: 'bob',
          delta: -10,
        );

        expect(game().damageFrom(atraxa.id, 'bob'), 0);
        // Life returns to 40, not 48.
        expect(lifeOf('bob'), 40);
      },
    );
  });

  group('the 21 damage threshold', () {
    test('20 from one commander is not lethal', () {
      final notifier = startGame();
      notifier.adjustCommanderDamage(
        sourceCardId: atraxa.id,
        targetProfileId: 'bob',
        delta: 20,
      );
      expect(game().isLethalCommanderDamage('bob'), isFalse);
    });

    test('21 from one commander is lethal', () {
      final notifier = startGame();
      notifier.adjustCommanderDamage(
        sourceCardId: atraxa.id,
        targetProfileId: 'bob',
        delta: 21,
      );
      expect(game().isLethalCommanderDamage('bob'), isTrue);
    });

    test('21 spread across two commanders is not lethal', () {
      final notifier = startGame();

      notifier.adjustCommanderDamage(
        sourceCardId: tymna.id,
        targetProfileId: 'bob',
        delta: 11,
      );
      notifier.adjustCommanderDamage(
        sourceCardId: thrasios.id,
        targetProfileId: 'bob',
        delta: 10,
      );

      // This is the rule people get wrong: the threshold is per commander.
      expect(game().isLethalCommanderDamage('bob'), isFalse);
    });
  });

  group('damage summaries', () {
    test('lists damage taken, highest first, ignoring zeroes', () {
      final notifier = startGame();

      notifier.adjustCommanderDamage(
        sourceCardId: tymna.id,
        targetProfileId: 'bob',
        delta: 4,
      );
      notifier.adjustCommanderDamage(
        sourceCardId: atraxa.id,
        targetProfileId: 'bob',
        delta: 12,
      );
      notifier.adjustCommanderDamage(
        sourceCardId: thrasios.id,
        targetProfileId: 'bob',
        delta: 0,
      );

      final taken = game().damageTakenBy('bob');
      expect(taken, hasLength(2));
      expect(taken.first.key.sourceCardId, atraxa.id);
      expect(taken.first.value, 12);
      expect(taken.last.value, 4);
    });

    test('a player with no damage has an empty summary', () {
      startGame();
      expect(game().damageTakenBy('dave'), isEmpty);
    });
  });
}

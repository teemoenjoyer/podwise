import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podwise/data/database.dart';
import 'package:podwise/domain/counters.dart';
import 'package:podwise/domain/models.dart';
import 'package:podwise/state/providers.dart';

/// Ten poison ends a game as surely as zero life does, and a table that never
/// entered its commanders should still be able to track commander damage.
void main() {
  late PodWiseDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = PodWiseDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    container
        .read(activeGameProvider.notifier)
        .start(
          startingLife: 40,
          players: const [
            PlayerProfile(id: 'a', name: 'Ana'),
            PlayerProfile(id: 'b', name: 'Ben'),
            PlayerProfile(id: 'c', name: 'Cal'),
          ],
        );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  ActiveGameNotifier notifier() => container.read(activeGameProvider.notifier);
  String? prompt() => container.read(eliminationPromptProvider);
  final poison = CounterPresets.poison.id;

  group('poison', () {
    test('ten poison raises the elimination prompt', () {
      notifier().adjustCounter('a', poison, 9);
      expect(prompt(), isNull, reason: 'nine poison is survivable');

      notifier().adjustCounter('a', poison, 1);
      expect(prompt(), 'a');
    });

    test('it is still only a prompt, never automatic', () {
      notifier().adjustCounter('a', poison, 10);

      // Commander has too many loss conditions for the app to decide.
      final seat = container
          .read(activeGameProvider)!
          .seats
          .firstWhere((s) => s.profileId == 'a');
      expect(seat.eliminated, isFalse);
    });

    test('it asks once, not on every counter after ten', () {
      notifier().adjustCounter('a', poison, 10);
      expect(prompt(), 'a');

      container.read(eliminationPromptProvider.notifier).state = null;
      notifier().adjustCounter('a', poison, 1);
      expect(prompt(), isNull);
    });

    test('dropping back below ten lets it ask again', () {
      notifier().adjustCounter('a', poison, 10);
      container.read(eliminationPromptProvider.notifier).state = null;

      notifier().adjustCounter('a', poison, -2);
      notifier().adjustCounter('a', poison, 2);
      expect(prompt(), 'a');
    });

    test('counters with no lethal threshold never prompt', () {
      notifier().adjustCounter('a', CounterPresets.treasure.id, 40);
      expect(prompt(), isNull);
    });
  });

  group('commander damage without a commander', () {
    test('every player can still deal it', () {
      final game = container.read(activeGameProvider)!;
      for (final seat in game.seats) {
        // Nobody picked a commander, but there is still one in each command
        // zone — the app just does not know its name.
        expect(seat.commanders.isEmpty, isTrue);
        expect(seat.damageSources, hasLength(1));
        expect(seat.damageSources.single.name, contains(seat.name));
      }
    });

    test('the stand-in source is stable and unique per player', () {
      final game = container.read(activeGameProvider)!;
      final ids = [for (final s in game.seats) s.damageSources.single.id];

      expect(ids.toSet(), hasLength(3));
      // Namespaced so it can never collide with a Scryfall id.
      expect(ids.every((id) => id.startsWith('seat:')), isTrue);
    });

    test('damage tracks per source and reduces life', () {
      final game = container.read(activeGameProvider)!;
      final ben = game.seats.firstWhere((s) => s.profileId == 'b');

      notifier().adjustCommanderDamage(
        sourceCardId: ben.damageSources.single.id,
        targetProfileId: 'a',
        delta: 7,
      );

      final after = container.read(activeGameProvider)!;
      expect(after.damageFrom(ben.damageSources.single.id, 'a'), 7);
      // Commander damage is also normal damage.
      expect(after.seats.firstWhere((s) => s.profileId == 'a').life, 33);
    });

    test('reaching twenty-one raises the elimination prompt by itself', () {
      final game = container.read(activeGameProvider)!;
      final ben = game.seats.firstWhere((s) => s.profileId == 'b');

      notifier().adjustCommanderDamage(
        sourceCardId: ben.damageSources.single.id,
        targetProfileId: 'a',
        delta: 20,
      );
      expect(prompt(), isNull, reason: 'twenty is survivable');

      notifier().adjustCommanderDamage(
        sourceCardId: ben.damageSources.single.id,
        targetProfileId: 'a',
        delta: 1,
      );

      // Twenty-one from a full forty leaves nineteen life, so life alone
      // would never have raised this.
      expect(prompt(), 'a');
      expect(
        container
            .read(activeGameProvider)!
            .seats
            .firstWhere((s) => s.profileId == 'a')
            .life,
        19,
      );
    });

    test('twenty-one from one unnamed commander is still lethal', () {
      final game = container.read(activeGameProvider)!;
      final ben = game.seats.firstWhere((s) => s.profileId == 'b');
      final cal = game.seats.firstWhere((s) => s.profileId == 'c');

      notifier().adjustCommanderDamage(
        sourceCardId: ben.damageSources.single.id,
        targetProfileId: 'a',
        delta: 15,
      );
      notifier().adjustCommanderDamage(
        sourceCardId: cal.damageSources.single.id,
        targetProfileId: 'a',
        delta: 15,
      );

      // Thirty across two commanders is not lethal; the threshold is per
      // commander, and this is exactly why they are tracked separately.
      expect(
        container.read(activeGameProvider)!.isLethalCommanderDamage('a'),
        isFalse,
      );

      notifier().adjustCommanderDamage(
        sourceCardId: ben.damageSources.single.id,
        targetProfileId: 'a',
        delta: 6,
      );
      expect(
        container.read(activeGameProvider)!.isLethalCommanderDamage('a'),
        isTrue,
      );
    });
  });
}

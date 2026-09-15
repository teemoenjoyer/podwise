import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podwise/data/database.dart';
import 'package:podwise/domain/counters.dart';
import 'package:podwise/domain/models.dart';
import 'package:podwise/state/providers.dart';

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
  GameState game() => container.read(activeGameProvider)!;
  Seat seat(String id) => game().seats.firstWhere((s) => s.profileId == id);

  group('counters', () {
    test('accumulate per player without touching others', () {
      notifier().adjustCounter('a', CounterPresets.poison.id, 3);
      notifier().adjustCounter('a', CounterPresets.poison.id, 2);
      notifier().adjustCounter('b', CounterPresets.poison.id, 1);

      expect(seat('a').counters[CounterPresets.poison.id], 5);
      expect(seat('b').counters[CounterPresets.poison.id], 1);
      expect(seat('c').counters[CounterPresets.poison.id], isNull);
    });

    test('never go below zero', () {
      notifier().adjustCounter('a', CounterPresets.energy.id, 2);
      notifier().adjustCounter('a', CounterPresets.energy.id, -10);
      expect(seat('a').counters[CounterPresets.energy.id], 0);
    });

    test('different counter types are independent', () {
      notifier().adjustCounter('a', CounterPresets.poison.id, 4);
      notifier().adjustCounter('a', CounterPresets.energy.id, 7);

      expect(seat('a').counters[CounterPresets.poison.id], 4);
      expect(seat('a').counters[CounterPresets.energy.id], 7);
    });

    test('a custom counter works like any preset', () {
      final spore = CounterPresets.custom('Spore');
      notifier().adjustCounter('a', spore.id, 3);
      expect(seat('a').counters[spore.id], 3);
      expect(spore.label, 'Spore');
    });

    test('removing a counter clears it entirely', () {
      notifier().adjustCounter('a', CounterPresets.storm.id, 5);
      notifier().removeCounter('a', CounterPresets.storm.id);
      expect(seat('a').counters.containsKey(CounterPresets.storm.id), isFalse);
    });

    test('poison is lethal at ten, not fifteen', () {
      // Commander uses the normal 10, which players coming from other formats
      // sometimes get wrong.
      expect(CounterPresets.poison.isLethal(9), isFalse);
      expect(CounterPresets.poison.isLethal(10), isTrue);
    });

    test('commander tax steps in twos', () {
      expect(CounterPresets.commanderTax.step, 2);
      expect(CounterPresets.poison.step, 1);
    });
  });

  group('status effects', () {
    test('a plain status toggles on and off', () {
      notifier().toggleStatus('a', StatusPresets.citysBlessing);
      expect(seat('a').statuses, contains(StatusPresets.citysBlessing.id));

      notifier().toggleStatus('a', StatusPresets.citysBlessing);
      expect(
        seat('a').statuses,
        isNot(contains(StatusPresets.citysBlessing.id)),
      );
    });

    test("City's Blessing can be held by everyone at once", () {
      notifier().toggleStatus('a', StatusPresets.citysBlessing);
      notifier().toggleStatus('b', StatusPresets.citysBlessing);

      expect(seat('a').statuses, contains(StatusPresets.citysBlessing.id));
      expect(seat('b').statuses, contains(StatusPresets.citysBlessing.id));
    });

    test('the Monarch moves rather than duplicating', () {
      notifier().toggleStatus('a', StatusPresets.monarch);
      expect(seat('a').statuses, contains(StatusPresets.monarch.id));

      // Ben steals it.
      notifier().toggleStatus('b', StatusPresets.monarch);
      expect(seat('b').statuses, contains(StatusPresets.monarch.id));
      expect(
        seat('a').statuses,
        isNot(contains(StatusPresets.monarch.id)),
        reason: 'only one player can be the Monarch',
      );
    });

    test('the Initiative also moves', () {
      notifier().toggleStatus('a', StatusPresets.initiative);
      notifier().toggleStatus('c', StatusPresets.initiative);

      expect(seat('c').statuses, contains(StatusPresets.initiative.id));
      expect(seat('a').statuses, isNot(contains(StatusPresets.initiative.id)));
    });

    test('Monarch and Initiative are independent of each other', () {
      notifier().toggleStatus('a', StatusPresets.monarch);
      notifier().toggleStatus('b', StatusPresets.initiative);

      expect(seat('a').statuses, contains(StatusPresets.monarch.id));
      expect(seat('b').statuses, contains(StatusPresets.initiative.id));
    });

    test('Day replaces Night', () {
      notifier().toggleStatus('a', StatusPresets.night);
      expect(seat('a').statuses, contains(StatusPresets.night.id));

      notifier().toggleStatus('a', StatusPresets.day);
      expect(seat('a').statuses, contains(StatusPresets.day.id));
      expect(
        seat('a').statuses,
        isNot(contains(StatusPresets.night.id)),
        reason: 'it cannot be both day and night',
      );
    });

    test('Night set by one player clears Day held by another', () {
      notifier().toggleStatus('a', StatusPresets.day);
      notifier().toggleStatus('b', StatusPresets.night);

      expect(seat('b').statuses, contains(StatusPresets.night.id));
      expect(
        seat('a').statuses,
        isNot(contains(StatusPresets.day.id)),
        reason: 'day/night describe the game, not one player',
      );
    });

    test('turning a status off does not disturb other players', () {
      notifier().toggleStatus('a', StatusPresets.citysBlessing);
      notifier().toggleStatus('b', StatusPresets.citysBlessing);
      notifier().toggleStatus('a', StatusPresets.citysBlessing);

      expect(seat('b').statuses, contains(StatusPresets.citysBlessing.id));
    });
  });
}

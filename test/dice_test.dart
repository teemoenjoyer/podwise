import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:podwise/domain/dice.dart';

/// The one thing that must not be left to chance in a randomiser is the bit
/// that isn't random: a die has to stay inside its own range, and the spinner
/// has to stop on the player it actually picked.
void main() {
  group('dice', () {
    test('every die stays within its own range', () {
      final random = Random(7);
      for (final die in DieType.values) {
        for (var i = 0; i < 2000; i++) {
          final roll = rollDie(die, random);
          expect(roll, greaterThanOrEqualTo(1));
          expect(roll, lessThanOrEqualTo(die.sides));
        }
      }
    });

    test('a die can roll both its extremes', () {
      final random = Random(3);
      final seen = {
        for (var i = 0; i < 4000; i++) rollDie(DieType.d20, random),
      };
      // Off-by-one here would quietly make a natural 20 impossible.
      expect(seen, contains(1));
      expect(seen, contains(20));
      expect(seen.length, 20);
    });

    test('labels read the way players say them', () {
      expect(DieType.values.map((d) => d.label), ['d4', 'd6', 'd10', 'd20']);
    });
  });

  group('the first-turn spinner', () {
    test('always finishes on the seat that was chosen', () {
      // The animation is cosmetic; landing somewhere other than the drawn
      // seat would make the app lie to the table.
      for (var seats = 2; seats <= 6; seats++) {
        for (var landsOn = 0; landsOn < seats; landsOn++) {
          expect(
            spinIndexAt(progress: 1, seatCount: seats, landsOn: landsOn),
            landsOn,
            reason: '$seats seats landing on $landsOn',
          );
        }
      }
    });

    test('stays in range the whole way round', () {
      for (var step = 0; step <= 100; step++) {
        final index = spinIndexAt(
          progress: step / 100,
          seatCount: 5,
          landsOn: 3,
        );
        expect(index, inInclusiveRange(0, 4));
      }
    });

    test('passes over every seat on the way', () {
      final visited = {
        for (var step = 0; step <= 200; step++)
          spinIndexAt(progress: step / 200, seatCount: 4, landsOn: 2),
      };
      // A spinner that only ever lit one or two names would not read as a
      // draw at all.
      expect(visited, {0, 1, 2, 3});
    });

    test('an empty table does not crash it', () {
      expect(spinIndexAt(progress: 0.5, seatCount: 0, landsOn: 0), 0);
      expect(pickSeatIndex(0, Random(1)), 0);
    });

    test('the draw reaches every seat', () {
      final random = Random(11);
      final drawn = {for (var i = 0; i < 500; i++) pickSeatIndex(4, random)};
      expect(drawn, {0, 1, 2, 3});
    });
  });
}

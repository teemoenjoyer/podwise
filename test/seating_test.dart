import 'package:flutter_test/flutter_test.dart';
import 'package:podwise/domain/seating.dart';

/// How a table arranges itself around the phone.
///
/// The defaults matter most: this replaced a hand-written table of row sizes,
/// and a board that silently reshuffles who sits where would move somebody's
/// life total out from under their finger mid-game.
void main() {
  group('defaults', () {
    test('every table size keeps the layout it had before', () {
      // The fixed table this replaced, verbatim. Any drift here is a visible
      // change to a board somebody is already used to.
      const previous = {
        2: [1, 1],
        3: [1, 2],
        4: [2, 2],
        5: [2, 3],
        6: [3, 3],
        7: [3, 4],
        8: [4, 4],
        9: [4, 5],
        10: [5, 5],
      };

      for (final entry in previous.entries) {
        expect(
          Seating.rows(entry.key, null),
          entry.value,
          reason: '${entry.key} players',
        );
      }
    });

    test('the larger half sits nearest', () {
      // Odd tables put the extra seat on the near side, which is the half the
      // phone's owner is sitting on.
      expect(Seating.rows(5, null), [2, 3]);
      expect(Seating.rows(7, null), [3, 4]);
    });
  });

  group('arrangements', () {
    test('every seat count can be split any way', () {
      expect(Seating.optionsFor(4), [0, 1, 2, 3]);
    });

    test('the same layout is never offered twice', () {
      // Everybody far and everybody near both render as one row facing the
      // same way, so listing both put "All 3 on one side" in the menu twice.
      for (var players = 1; players <= 10; players++) {
        final layouts = [
          for (final far in Seating.optionsFor(players))
            Seating.rows(players, far).join(','),
        ];
        expect(
          layouts.toSet(),
          hasLength(layouts.length),
          reason: '$players players offers a duplicate layout',
        );
      }
    });

    test('every distinct split is still reachable', () {
      // Dropping the duplicate must not drop a real arrangement with it.
      for (var players = 1; players <= 10; players++) {
        final reachable = {
          for (final far in Seating.optionsFor(players))
            Seating.rows(players, far).join(','),
        };
        for (var far = 0; far <= players; far++) {
          expect(
            reachable,
            contains(Seating.rows(players, far).join(',')),
            reason: '$players players cannot reach far=$far',
          );
        }
      }
    });

    test('a chosen split is honoured', () {
      expect(Seating.rows(4, 1), [1, 3]);
      expect(Seating.rows(4, 3), [3, 1]);
    });

    test('everybody on one side is a single row, not a blank half', () {
      // Two people on a sofa is a real way to play, and the old fixed layout
      // could not express it.
      expect(Seating.rows(2, 0), [2]);
      expect(Seating.rows(2, 2), [2]);
      expect(Seating.rows(5, 0), [5]);
    });

    test('a nonsense split is clamped rather than crashing the board', () {
      expect(Seating.rows(4, 99), [4]);
      expect(Seating.rows(4, -3), [4]);
    });

    test('an empty table does not produce an empty row', () {
      expect(Seating.rows(0, null), isEmpty);
    });

    test('every arrangement seats exactly everybody', () {
      for (var players = 1; players <= 10; players++) {
        for (final far in Seating.optionsFor(players)) {
          final rows = Seating.rows(players, far);
          expect(
            rows.fold<int>(0, (a, b) => a + b),
            players,
            reason: '$players players, $far on the far side',
          );
          expect(rows.any((r) => r == 0), isFalse);
        }
      }
    });
  });

  group('which way a row faces', () {
    test('the far row is upside-down and the near row is not', () {
      expect(Seating.isFlipped(0, 2), isTrue);
      expect(Seating.isFlipped(1, 2), isFalse);
    });

    test('one row is never flipped', () {
      // Nobody is opposite anybody, so flipping it would leave the whole table
      // reading their own life totals upside-down.
      expect(Seating.isFlipped(0, 1), isFalse);
    });
  });

  group('how it reads in the menu', () {
    test('a split names both sides', () {
      expect(Seating.describe(4, 1), '1 across from 3');
      expect(Seating.describe(4, 2), '2 across from 2');
    });

    test('one side is described as one side, either way round', () {
      expect(Seating.describe(3, 0), 'All 3 on one side');
      expect(Seating.describe(3, 3), 'All 3 on one side');
    });
  });

  group('moving players', () {
    test('a swap exchanges two seats and leaves the rest alone', () {
      expect(Seating.swap([1, 2, 3, 4], 0, 3), [4, 2, 3, 1]);
    });

    test('swapping a seat with itself changes nothing', () {
      expect(Seating.swap([1, 2, 3], 1, 1), [1, 2, 3]);
    });

    test('an out-of-range swap is refused rather than throwing', () {
      // A board mid-rearrange is not worth crashing over.
      expect(Seating.swap([1, 2, 3], 0, 9), [1, 2, 3]);
      expect(Seating.swap([1, 2, 3], -1, 0), [1, 2, 3]);
      expect(Seating.swap(<int>[], 0, 1), isEmpty);
    });

    test('a swap does not mutate the list it was given', () {
      // Seats live in immutable state; mutating in place would leave the two
      // copies disagreeing about who sits where.
      final original = [1, 2, 3];
      Seating.swap(original, 0, 2);
      expect(original, [1, 2, 3]);
    });

    test('shuffling up moves everybody round one', () {
      expect(Seating.rotate([1, 2, 3, 4]), [2, 3, 4, 1]);
    });

    test('shuffling up all the way round returns to the start', () {
      expect(Seating.rotate([1, 2, 3], 3), [1, 2, 3]);
      expect(Seating.rotate([1, 2, 3], 4), Seating.rotate([1, 2, 3], 1));
    });

    test('a table of one has nowhere to shuffle to', () {
      expect(Seating.rotate([1]), [1]);
      expect(Seating.rotate(<int>[]), isEmpty);
    });

    test('nobody is lost or duplicated by any move', () {
      final seats = [1, 2, 3, 4, 5];
      for (var a = 0; a < 5; a++) {
        for (var b = 0; b < 5; b++) {
          expect(Seating.swap(seats, a, b).toSet(), seats.toSet());
        }
      }
      for (var by = 0; by < 7; by++) {
        expect(Seating.rotate(seats, by).toSet(), seats.toSet());
      }
    });
  });
}

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:podwise/domain/celebration.dart';

/// The burst is decoration, so the only things worth pinning are the ones
/// that would leave something visibly wrong on screen: sparks appearing away
/// from where they were thrown, sparks still sitting there once it is over,
/// and a burst that goes one way instead of outwards.
void main() {
  group('sparkBurst', () {
    test('throws sparks all the way round', () {
      final sparks = sparkBurst(count: 24, random: Random(7));

      // Quadrant by quadrant, because a burst that misses one reads as a
      // spill out of the side of the pill rather than a celebration.
      final quadrants = {
        for (final spark in sparks)
          (sparkAt(spark, 0.3).dx >= 0, sparkAt(spark, 0.3).dy >= 0),
      };
      expect(quadrants, hasLength(4));
    });

    test('the same seed gives the same burst', () {
      double first(Random r) => sparkBurst(count: 6, random: r).first.angle;
      expect(first(Random(3)), first(Random(3)));
    });

    test('asking for nothing is not an error', () {
      expect(sparkBurst(count: 0, random: Random(1)), isEmpty);
      expect(sparkBurst(count: -4, random: Random(1)), isEmpty);
    });

    test('colours stay within the palette asked for', () {
      final sparks = sparkBurst(count: 40, random: Random(9), colours: 3);
      expect(sparks.every((s) => s.colorIndex >= 0 && s.colorIndex < 3), isTrue);
    });
  });

  group('sparkAt', () {
    final sparks = sparkBurst(count: 30, random: Random(5));

    test('everything starts at the origin, invisible', () {
      for (final spark in sparks) {
        final frame = sparkAt(spark, 0);
        expect(frame.dx, closeTo(0, 1e-9));
        expect(frame.dy, closeTo(0, 1e-9));
        expect(frame.opacity, closeTo(0, 1e-9));
      }
    });

    test('nothing is left on screen at the end', () {
      // A spark still drawn at full opacity when the controller stops would
      // sit frozen over the dialog until it was dismissed.
      for (final spark in sparks) {
        expect(sparkAt(spark, 1).opacity, closeTo(0, 1e-9));
      }
    });

    test('opacity and scale stay drawable the whole way through', () {
      for (final spark in sparks) {
        for (var step = 0; step <= 50; step++) {
          final frame = sparkAt(spark, step / 50);
          expect(frame.opacity, inInclusiveRange(0, 1));
          // Zero is fine — sparks pop up from nothing — but a negative scale
          // would draw every one of them mirrored.
          expect(frame.scale, greaterThanOrEqualTo(0));
          expect(frame.dx.isFinite && frame.dy.isFinite, isTrue);
        }
      }
    });

    test('progress outside 0 to 1 is clamped, not extrapolated', () {
      // The controller can overshoot by a hair between frames, and a spark
      // flying off to infinity because of it would be a real bug.
      expect(sparkAt(sparks.first, 2).opacity, closeTo(0, 1e-9));
      expect(sparkAt(sparks.first, -1).dx, closeTo(0, 1e-9));
    });

    test('sparks arc rather than flying straight', () {
      // One thrown straight up must come back down: without gravity the
      // burst looks like a starburst decal instead of something thrown.
      final up = Spark(
        angle: pi / 2,
        speed: 1,
        spin: 0,
        size: 1,
        colorIndex: 0,
      );
      expect(sparkAt(up, 0.3).dy, lessThan(0));
      expect(sparkAt(up, 1).dy, greaterThan(sparkAt(up, 0.3).dy));
    });
  });
}

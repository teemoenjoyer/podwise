import 'dart:math';

/// One spark thrown out when the first-player draw lands.
///
/// Held as the parameters of a trajectory rather than a position, so a burst
/// is drawn by asking [sparkAt] where each spark is at a given moment. That
/// keeps the whole thing pure: no per-frame state to tick, nothing to get out
/// of step, and an animation that is identical every time for a given seed.
class Spark {
  const Spark({
    required this.angle,
    required this.speed,
    required this.spin,
    required this.size,
    required this.colorIndex,
  });

  /// Radians, measured anticlockwise from straight out to the right.
  final double angle;

  /// How far out it flies, as a fraction of the burst radius.
  final double speed;

  /// Turns over the life of the burst. Negative spins the other way.
  final double spin;

  /// Fraction of the largest spark.
  final double size;

  /// Index into whatever palette the painter is using.
  final int colorIndex;
}

/// Where a spark is part-way through the burst.
///
/// [dx] and [dy] are fractions of the burst radius from its origin, in screen
/// terms — positive [dy] is downwards.
typedef SparkFrame = ({
  double dx,
  double dy,
  double turns,
  double opacity,
  double scale,
});

/// How hard the sparks are pulled back down, relative to how hard they were
/// thrown. Enough that they arc rather than flying off in a straight line.
const double _gravity = 0.9;

/// Throws [count] sparks outwards.
///
/// Angles are spaced evenly and then jittered within their own slot, because
/// picking each one at random leaves gaps and clumps that read as a spill
/// rather than a burst.
List<Spark> sparkBurst({
  required int count,
  required Random random,
  int colours = 4,
}) {
  if (count <= 0) return const [];
  final slot = 2 * pi / count;

  return [
    for (var i = 0; i < count; i++)
      Spark(
        angle: i * slot + (random.nextDouble() - 0.5) * slot,
        speed: 0.55 + random.nextDouble() * 0.45,
        spin: (random.nextDouble() * 2 - 1) * 1.5,
        size: 0.6 + random.nextDouble() * 0.4,
        colorIndex: random.nextInt(max(colours, 1)),
      ),
  ];
}

/// Places [spark] at [progress], which runs 0 to 1 over the whole burst.
///
/// Every spark starts at the origin and ends invisible, so a burst leaves
/// nothing behind on the screen when it is over.
SparkFrame sparkAt(Spark spark, double progress) {
  final t = progress.clamp(0.0, 1.0);

  // Decelerating: they leap away and then drift, which is what a spark thrown
  // through air actually does.
  final travel = 1 - pow(1 - t, 3).toDouble();

  return (
    dx: cos(spark.angle) * spark.speed * travel,
    dy: -sin(spark.angle) * spark.speed * travel + _gravity * t * t,
    turns: spark.spin * t,
    // Fades up over the first instant so nothing appears mid-air, then out
    // across the rest.
    opacity: t < 0.1 ? t / 0.1 : (1 - t) / 0.9,
    scale: t < 0.2 ? t / 0.2 : 1 - 0.45 * ((t - 0.2) / 0.8),
  );
}

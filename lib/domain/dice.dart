import 'dart:math';

/// The dice a Commander table actually reaches for.
///
/// Deliberately not the full polyhedral set — d8 and d12 come up rarely enough
/// that offering seven options would make the common four harder to hit.
enum DieType {
  d4(4),
  d6(6),
  d10(10),
  d20(20);

  const DieType(this.sides);

  final int sides;

  String get label => 'd$sides';
}

/// One roll, 1 to [DieType.sides] inclusive.
///
/// Takes its [Random] rather than making one, so a test can pin the outcome
/// instead of hoping.
int rollDie(DieType die, Random random) => random.nextInt(die.sides) + 1;

/// Picks a seat at random, by index.
int pickSeatIndex(int seatCount, Random random) =>
    seatCount <= 0 ? 0 : random.nextInt(seatCount);

/// Which seat the "who goes first" spinner is pointing at, part-way through.
///
/// Pure, because the one thing that must not be left to chance is that the
/// animation finishes on the seat that was actually chosen. Progress runs 0
/// to 1; at 1 this returns [landsOn] exactly, whatever [loops] is.
int spinIndexAt({
  required double progress,
  required int seatCount,
  required int landsOn,
  int loops = 3,
}) {
  if (seatCount <= 0) return 0;
  final steps = loops * seatCount + landsOn;
  if (progress >= 1) return landsOn;
  return (steps * progress).floor() % seatCount;
}

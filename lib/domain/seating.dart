/// How a table arranges itself around a phone lying flat in the middle.
///
/// The board is landscape and splits into at most two rows, because a third
/// row would face sideways to everybody at the table. A layout is therefore
/// just one number: how many seats go in the **far** row, the one rendered
/// upside-down for the players sitting opposite. The rest sit near.
///
/// Pure so the arrangements can be tested without a board to draw them on.
abstract final class Seating {
  /// The far-row size a table of [players] gets unless somebody picks another.
  ///
  /// Split as evenly as possible with the larger half nearest — a table of
  /// five is three on the far side and two near, which matches how people
  /// actually sit when one side of the table has more room.
  static int defaultFarRow(int players) => players ~/ 2;

  /// Every *distinct* arrangement offered for [players], far-row size first.
  ///
  /// Includes putting everybody on one side, which is how two people sitting
  /// next to each other on a sofa actually play, and is the arrangement the
  /// fixed layout could never express.
  ///
  /// Stops one short of [players] on purpose: everybody in the far row and
  /// everybody in the near row both come out as a single row facing the same
  /// way, so offering both would list the same layout twice.
  static List<int> optionsFor(int players) {
    if (players <= 0) return const [0];
    return [for (var far = 0; far < players; far++) far];
  }

  /// The row sizes for [players] with [farRow] on the far side.
  ///
  /// A row of zero is dropped rather than rendered empty, so everybody on one
  /// side gives a single row rather than a blank half-board.
  static List<int> rows(int players, int? farRow) {
    final far = (farRow ?? defaultFarRow(players)).clamp(0, players);
    final near = players - far;
    return [
      if (far > 0) far,
      if (near > 0) near,
    ];
  }

  /// Whether the row at [index] of [rowCount] faces the far side of the table.
  ///
  /// With two rows the first is flipped. With one, nobody is opposite anybody,
  /// so it reads the right way up for the side everyone is sitting on.
  static bool isFlipped(int index, int rowCount) =>
      rowCount > 1 && index < rowCount / 2;

  /// Swaps the players in seats [a] and [b], leaving everyone else put.
  ///
  /// Seats are only a running order: life, counters, commander damage and
  /// knockout order all hang off the player, not their position, so moving
  /// two people takes their totals with them and touches nothing else.
  ///
  /// Out-of-range indices are returned unchanged rather than throwing — a
  /// board mid-rearrange is not worth crashing over.
  static List<T> swap<T>(List<T> seats, int a, int b) {
    if (a == b) return seats;
    if (a < 0 || b < 0 || a >= seats.length || b >= seats.length) return seats;
    final moved = [...seats];
    final held = moved[a];
    moved[a] = moved[b];
    moved[b] = held;
    return moved;
  }

  /// Moves everybody round one place, which is what a table does when it
  /// shuffles up rather than swapping two people.
  static List<T> rotate<T>(List<T> seats, [int by = 1]) {
    if (seats.length < 2) return seats;
    final shift = by % seats.length;
    if (shift == 0) return seats;
    return [...seats.sublist(shift), ...seats.sublist(0, shift)];
  }

  /// How an arrangement reads in a menu.
  static String describe(int players, int farRow) {
    final far = farRow.clamp(0, players);
    final near = players - far;
    if (far == 0 || near == 0) return 'All $players on one side';
    return '$far across from $near';
  }
}

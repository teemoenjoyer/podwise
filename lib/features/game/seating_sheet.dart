import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/feedback.dart';
import '../../core/theme.dart';
import '../../domain/models.dart';
import '../../domain/seating.dart';
import '../../state/providers.dart';
import '../../state/settings_providers.dart';

/// Where everyone is sitting, and how to change it mid-game.
///
/// Two separate things, because a table gets them wrong in two different ways:
/// the shape of the table — how many face each way — and who is in which
/// chair. Both are commonly sorted out only after the game has started.
class SeatingSheet extends ConsumerStatefulWidget {
  const SeatingSheet({super.key});

  @override
  ConsumerState<SeatingSheet> createState() => _SeatingSheetState();
}

class _SeatingSheetState extends ConsumerState<SeatingSheet> {
  /// The seat waiting to be swapped with whatever is tapped next.
  int? _picked;

  void _tapSeat(int index) {
    final feedback = ref.read(feedbackProvider);
    if (_picked == null) {
      feedback.fire(FeedbackEvent.selection);
      setState(() => _picked = index);
      return;
    }
    if (_picked == index) {
      setState(() => _picked = null);
      return;
    }
    // Everything about a player is keyed by their id, so life, counters,
    // commander damage and knockout order all travel with them.
    ref.read(activeGameProvider.notifier).swapSeats(_picked!, index);
    feedback.fire(FeedbackEvent.bigSwing);
    setState(() => _picked = null);
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(activeGameProvider);
    if (game == null) return const SizedBox.shrink();

    final players = game.seats.length;
    final far = game.farRowSeats ?? Seating.defaultFarRow(players);
    final rows = Seating.rows(players, far);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Seating',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
                if (players > 1)
                  TextButton.icon(
                    onPressed: () {
                      ref.read(feedbackProvider).fire(FeedbackEvent.selection);
                      ref.read(activeGameProvider.notifier).rotateSeats();
                      setState(() => _picked = null);
                    },
                    icon: const Icon(Icons.rotate_right_rounded, size: 18),
                    label: const Text('SHUFFLE UP'),
                  ),
              ],
            ),
            Text(
              _picked == null
                  ? 'Tap two players to swap seats. Names shown upside-down are '
                        'the ones facing the far side of the table.'
                  : 'Now tap whoever ${game.seats[_picked!].name} is swapping '
                        'with.',
              style: TextStyle(
                fontSize: 12,
                color: _picked == null
                    ? Colors.white.withValues(alpha: 0.55)
                    : PodWiseColors.accent,
              ),
            ),
            const SizedBox(height: 12),
            _SeatingMap(
              game: game,
              rows: rows,
              picked: _picked,
              onTap: _tapSeat,
            ),
            const SizedBox(height: 18),
            Text(
              'WHICH WAY ROUND',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: Colors.white.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 14,
              runSpacing: 14,
              alignment: WrapAlignment.center,
              children: [
                for (final option in Seating.optionsFor(players))
                  _SeatingChoice(
                    players: players,
                    farRow: option,
                    selected: option == far,
                    onTap: () {
                      ref.read(feedbackProvider).fire(FeedbackEvent.selection);
                      ref.read(activeGameProvider.notifier).setSeating(option);
                      // Left open on purpose: the change shows up in the map
                      // above, which is usually the moment somebody notices
                      // two people need swapping as well.
                      setState(() => _picked = null);
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The table as it stands, with names in the seats.
class _SeatingMap extends StatelessWidget {
  const _SeatingMap({
    required this.game,
    required this.rows,
    required this.picked,
    required this.onTap,
  });

  final GameState game;
  final List<int> rows;
  final int? picked;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    var index = 0;
    final rowWidgets = <Widget>[];

    for (var r = 0; r < rows.length; r++) {
      final flipped = Seating.isFlipped(r, rows.length);
      final cells = <Widget>[];
      for (var c = 0; c < rows[r]; c++) {
        final seatIndex = index++;
        if (c > 0) cells.add(const SizedBox(width: 8));
        cells.add(
          Expanded(
            child: _SeatCell(
              seat: game.seats[seatIndex],
              flipped: flipped,
              picked: picked == seatIndex,
              onTap: () => onTap(seatIndex),
            ),
          ),
        );
      }
      if (r > 0) rowWidgets.add(const SizedBox(height: 8));
      rowWidgets.add(SizedBox(height: 50, child: Row(children: cells)));
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: PodWiseColors.outline),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: rowWidgets),
    );
  }
}

class _SeatCell extends StatelessWidget {
  const _SeatCell({
    required this.seat,
    required this.flipped,
    required this.picked,
    required this.onTap,
  });

  final Seat seat;
  final bool flipped;
  final bool picked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colour =
        PodWiseColors.seats[seat.colorIndex % PodWiseColors.seats.length];

    final label = Text(
      seat.name.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
        color: Colors.white.withValues(alpha: seat.eliminated ? 0.35 : 0.9),
      ),
    );

    return Semantics(
      label: '${seat.name}, ${flipped ? 'far side' : 'near side'}',
      button: true,
      selected: picked,
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: colour.withValues(alpha: picked ? 0.45 : 0.18),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: picked
                  ? PodWiseColors.accent
                  : colour.withValues(alpha: 0.5),
              width: picked ? 2 : 1,
            ),
          ),
          // Drawn the way the board will draw it, so the map shows which names
          // end up facing the other side rather than describing it.
          child: flipped ? RotatedBox(quarterTurns: 2, child: label) : label,
        ),
      ),
    );
  }
}

/// One seating arrangement, drawn rather than described.
///
/// A picture of the table says in one glance what "1 across from 2" makes you
/// work out, and it is the same shape as the board it is about to produce.
class _SeatingChoice extends StatelessWidget {
  const _SeatingChoice({
    required this.players,
    required this.farRow,
    required this.selected,
    required this.onTap,
  });

  final int players;
  final int farRow;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final rows = Seating.rows(players, farRow);
    final accent = selected
        ? PodWiseColors.accent
        : Colors.white.withValues(alpha: 0.55);

    return Semantics(
      // The description the diagram replaces, kept for screen readers.
      label: Seating.describe(players, farRow),
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: 104,
          height: 66,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            // The outline is the phone the panels are drawn on.
            color: selected
                ? PodWiseColors.accent.withValues(alpha: 0.10)
                : null,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? PodWiseColors.accent : PodWiseColors.outline,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              for (var r = 0; r < rows.length; r++) ...[
                if (r > 0) const SizedBox(height: 5),
                Expanded(
                  child: Row(
                    // Stretched, or an empty DecoratedBox collapses to no
                    // height and the whole diagram draws as a blank box.
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var c = 0; c < rows[r]; c++) ...[
                        if (c > 0) const SizedBox(width: 5),
                        Expanded(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              // Faded where the row faces the other way, so
                              // which half is upside-down is visible without
                              // reading anything.
                              color: accent.withValues(
                                alpha: Seating.isFlipped(r, rows.length)
                                    ? 0.3
                                    : 0.85,
                              ),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

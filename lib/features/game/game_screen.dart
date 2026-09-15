import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../domain/counters.dart';
import '../../domain/models.dart';
import '../../domain/seating.dart';
import '../../state/providers.dart';
import '../../state/settings_providers.dart';
import '../../state/transfer_providers.dart';
import '../transfer/show_code_screen.dart';
import 'dice_sheet.dart';
import 'first_player_dialog.dart';
import 'commander_damage_sheet.dart';
import 'game_timer_pill.dart';
import 'counters_sheet.dart';
import 'game_summary_screen.dart';
import 'player_panel.dart';
import 'seating_sheet.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  @override
  void initState() {
    super.initState();
    // The game screen is the one place that wants landscape: it puts the phone
    // flat in the middle of the table with panels facing outwards. Every other
    // screen is a portrait list.
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Somebody has to go first, and a table that has just sat down is exactly
    // when it needs deciding — so it is offered unprompted, once. Anyone who
    // would rather sort it out themselves taps SKIP.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final game = ref.read(activeGameProvider);
      if (game == null || game.isFinished || game.firstPlayerAsked) return;
      if (game.seats.length < 2) return;
      _drawFirstPlayer(game);
    });
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  Future<void> _confirmFinish(GameState game) async {
    final notifier = ref.read(activeGameProvider.notifier);
    final winner = await showDialog<String?>(
      context: context,
      builder: (_) => _WinnerDialog(seats: game.seats),
    );
    if (winner == null || !mounted) return;

    // Navigation is left to the listener in [build], which also catches the
    // game ending on its own when the last-but-one player is knocked out.
    await notifier.finish(winnerProfileId: winner.isEmpty ? null : winner);
  }

  /// Stops a second route being pushed if the state settles twice.
  bool _endingShown = false;

  /// Leaves the board for whatever this game's ending is.
  void _showEnding(GameState finished) {
    if (_endingShown || !mounted) return;
    _endingShown = true;

    // Anything the game ended from — a counters sheet, a seat sheet — is still
    // on the stack, and replacing *that* would leave this screen alive
    // underneath, still holding the display in landscape. Close back to the
    // board first so the replacement actually replaces the board.
    final navigator = Navigator.of(context);
    final board = ModalRoute.of(context);
    if (board != null) navigator.popUntil((route) => route == board);

    // A borrowed pod has no summary to show here — it was never this phone's
    // game. Its ending is a code to hand back to whoever sent it.
    if (finished.isBorrowed) {
      final result = ref.read(transferServiceProvider).packResult(finished);
      navigator.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ShowCodeScreen(
            payload: result,
            title: 'Pod finished',
            instruction:
                'Show this to the phone that sent you the pod, so the result '
                'goes into their history.',
            footnote:
                'This result exists only here until they scan it. It is not '
                'saved on this phone.',
          ),
        ),
      );
      return;
    }

    navigator.pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const GameSummaryScreen()),
    );
  }

  void _openDice() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: PodWiseColors.surfaceRaised,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => DiceSheet(feedback: ref.read(feedbackProvider)),
    );
  }

  /// Offers the draw, and remembers the answer so it is not asked twice.
  Future<void> _drawFirstPlayer(GameState game) async {
    final chosen = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => FirstPlayerDialog(
        seats: game.seats,
        feedback: ref.read(feedbackProvider),
      ),
    );
    if (!mounted) return;
    // Recorded either way: skipping means "we will sort it ourselves", and
    // asking again on every return to the board would just be nagging.
    ref.read(activeGameProvider.notifier).recordFirstPlayerDraw(chosen);
  }

  Future<bool> _confirmAbandonBorrowed() async {
    final abandon = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: PodWiseColors.surfaceRaised,
        title: const Text('Lose this result?'),
        content: const Text(
          'Nobody else is tracking this game. If you abandon it now there is '
          'no result to hand back, and the phone that sent you the pod will '
          'never know how it ended.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('KEEP PLAYING'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: PodWiseColors.danger,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ABANDON'),
          ),
        ],
      ),
    );
    return abandon ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(activeGameProvider);
    if (game == null) {
      return const Scaffold(body: Center(child: Text('No game in progress')));
    }

    final notifier = ref.read(activeGameProvider.notifier);

    // The game can end without anyone opening the menu: knocking out the
    // last-but-one player settles it. Watching for the transition here means
    // both endings leave the board the same way.
    ref.listen<GameState?>(activeGameProvider, (previous, next) {
      if (next == null || !next.isFinished) return;
      if (previous?.isFinished ?? false) return;
      _showEnding(next);
    });

    // A player settling at 0 or below almost always means they're out, so ask
    // rather than making them dig through the menu.
    ref.listen<String?>(eliminationPromptProvider, (_, profileId) {
      if (profileId != null) _askAboutElimination(profileId);
    });

    final showTimer =
        ref.watch(settingsProvider).valueOrNull?.showTimer ?? true;
    final rows = Seating.rows(game.seats.length, game.farRowSeats);
    final compact = game.seats.length > 4 || rows.length > 2;

    var seatIndex = 0;
    final rowWidgets = <Widget>[];
    for (var r = 0; r < rows.length; r++) {
      final count = rows[r];
      // Everything above the midpoint faces the far side of the table —
      // unless the whole table is sitting on one side, in which case nobody
      // is opposite anybody and the row reads the right way up.
      final flipped = Seating.isFlipped(r, rows.length);
      rowWidgets.add(
        Expanded(
          child: Row(
            children: [
              for (var c = 0; c < count; c++)
                Expanded(
                  child: Builder(
                    builder: (_) {
                      final seat = game.seats[seatIndex++];
                      return PlayerPanel(
                        seat: seat,
                        pending: notifier.pendingFor(seat.profileId),
                        flipped: flipped,
                        compact: compact,
                        // A row of one runs the whole width, so its centre
                        // line is where the menu button sits.
                        spansFullWidth: count == 1,
                        worstCommanderDamage:
                            game
                                .damageTakenBy(seat.profileId)
                                .firstOrNull
                                ?.value ??
                            0,
                        onAdjust: (d) => notifier.adjustLife(seat.profileId, d),
                        onFeedback: (e) => ref.read(feedbackProvider).fire(e),
                        onOpenDetail: () => _openDetail(seat),
                        onOpenCommanderDamage: () =>
                            _openCommanderDamage(context, seat.profileId),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(4),
              child: Column(children: rowWidgets),
            ),
            // Centre control cluster: deliberately small so it never competes
            // with the life totals, and centred so it's reachable from any seat.
            Align(
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (showTimer) ...[
                    const GameTimerPill(),
                    const SizedBox(height: 6),
                  ],
                  _CentreControls(onMenu: () => _openMenu(game)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Says why this is being asked, not just that it is.
  ///
  /// Life is always shown — it is what the table is looking at — and anything
  /// else that has reached a lethal threshold is named alongside it. Without
  /// that, poison or commander damage produces "Jordan is at 40 life", which
  /// reads as the app asking at random.
  String _eliminationHeadline(GameState game, Seat seat) {
    final reasons = [
      for (final counter in CounterPresets.all)
        if (counter.isLethal(seat.counters[counter.id] ?? 0))
          '${seat.counters[counter.id]} ${counter.label.toLowerCase()}',
      ...?_lethalCommanderDamage(game, seat),
    ];

    final life = '${seat.name} is at ${seat.life} life';
    return reasons.isEmpty ? life : '$life, with ${reasons.join(' and ')}';
  }

  /// Twenty-one or more from a single commander, named.
  List<String>? _lethalCommanderDamage(GameState game, Seat seat) {
    final lethal = [
      for (final entry in game.damageTakenBy(seat.profileId))
        if (entry.value >= commanderDamageThreshold) entry,
    ];
    if (lethal.isEmpty) return null;

    // Sources live on the seat that owns them, so the name has to be looked
    // up across the table.
    String nameOf(String cardId) {
      for (final other in game.seats) {
        for (final card in other.damageSources) {
          if (card.id == cardId) return card.name;
        }
      }
      return 'a commander';
    }

    return [
      for (final entry in lethal)
        '${entry.value} commander damage from '
            '${nameOf(entry.key.sourceCardId)}',
    ];
  }

  Future<void> _askAboutElimination(String profileId) async {
    // Read fresh rather than trusting a seat captured during build: the
    // prompt fires as the state changes, so a snapshot taken a frame earlier
    // would not yet show the counter or damage that triggered it.
    final game = ref.read(activeGameProvider);
    final seat = game?.seats.where((s) => s.profileId == profileId).firstOrNull;
    if (game == null || seat == null) return;

    final eliminate = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: PodWiseColors.surfaceRaised,
        icon: Icon(
          Icons.heart_broken_rounded,
          color: PodWiseColors.danger,
          size: 32,
        ),
        scrollable: true,
        // Life alone would be baffling when it was poison that triggered
        // this: "Jordan is at 40 life" reads like the app asking at random.
        title: Text(_eliminationHeadline(game, seat)),
        // Without a cap this stretches the full width of a landscape screen,
        // which reads as one very long line.
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: const Text(
            'Are they out? Commander has other ways to lose, and effects can '
            'bring a player back, so nothing happens unless you say so.',
            textAlign: TextAlign.center,
          ),
        ),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('STILL IN'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: PodWiseColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('ELIMINATE'),
          ),
        ],
      ),
    );

    // Clear the request either way, so the same player can be asked again if
    // they heal up and drop back to zero later.
    ref.read(eliminationPromptProvider.notifier).state = null;

    if (eliminate ?? false) {
      ref.read(activeGameProvider.notifier).toggleEliminated(seat.profileId);
    }
  }

  /// Offers the ways this many players can sit around the phone, and lets the
  /// table swap places once they have actually sat down.
  Future<void> _chooseSeating() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: PodWiseColors.surfaceRaised,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => const SeatingSheet(),
    );
  }

  void _openDetail(Seat seat) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: PodWiseColors.surfaceRaised,
      showDragHandle: true,
      // The game screen is landscape-only, so sheets have little height to
      // work with and must be allowed to scroll.
      isScrollControlled: true,
      builder: (_) => _SeatSheet(seat: seat),
    );
  }

  void _openMenu(GameState game) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: PodWiseColors.surfaceRaised,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.flag_rounded),
                title: const Text('End game'),
                subtitle: const Text('Pick a winner and save to history'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _confirmFinish(game);
                },
              ),
              ListTile(
                leading: const Icon(Icons.casino_rounded),
                title: const Text('Roll dice'),
                subtitle: const Text('d4, d6, d10 or d20'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _openDice();
                },
              ),
              ListTile(
                leading: const Icon(Icons.shuffle_rounded),
                title: const Text('Who goes first?'),
                subtitle: Text(
                  game.firstPlayerId == null
                      ? 'Draw a player at random'
                      : 'Draw again',
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _drawFirstPlayer(game);
                },
              ),
              ListTile(
                leading: const Icon(Icons.event_seat_rounded),
                title: const Text('Seating'),
                subtitle: Text(
                  Seating.describe(
                    game.seats.length,
                    game.farRowSeats ?? Seating.defaultFarRow(game.seats.length),
                  ),
                ),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _chooseSeating();
                },
              ),
              ListTile(
                leading: const Icon(Icons.refresh_rounded),
                title: const Text('Reset life totals'),
                subtitle: Text('Back to ${game.startingLife} for everyone'),
                onTap: () {
                  ref.read(activeGameProvider.notifier).resetLife();
                  Navigator.of(sheetContext).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.close_rounded),
                title: const Text('Abandon game'),
                subtitle: Text(
                  // A borrowed pod is not recorded anywhere else, so
                  // abandoning it loses the result outright and the phone that
                  // sent it has no way of knowing.
                  game.isBorrowed
                      ? 'This pod exists nowhere else — its result will be lost'
                      : 'Discard without saving',
                ),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  if (game.isBorrowed && !await _confirmAbandonBorrowed()) {
                    return;
                  }
                  ref.read(activeGameProvider.notifier).clear();
                  if (mounted) Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// How many panels sit in each row, for a given player count.
///
/// Rows above the midpoint get rotated, so an even split puts half the table
/// on each side — which is how people actually sit around a pod.
/// How to divide the board into rows for a given number of players.
///
/// Always two rows: the phone lies flat between the players, so one row faces
/// each side of the table. A third row would face sideways to everybody.
class _CentreControls extends StatelessWidget {
  const _CentreControls({required this.onMenu});
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PodWiseColors.surfaceHigh,
      shape: const CircleBorder(),
      elevation: 6,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onMenu,
        child: const SizedBox(
          width: 56,
          height: 56,
          child: Icon(Icons.more_horiz_rounded, size: 26),
        ),
      ),
    );
  }
}

class _SeatSheet extends ConsumerWidget {
  const _SeatSheet({required this.seat});
  final Seat seat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(activeGameProvider.notifier);
    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                seat.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text('${seat.life} life'),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  for (final delta in [-10, -5, -1, 1, 5, 10])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 52),
                          ),
                          onPressed: () {
                            notifier.adjustLife(seat.profileId, delta);
                            Navigator.of(context).pop();
                          },
                          child: Text(delta > 0 ? '+$delta' : '$delta'),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.workspace_premium_outlined),
              title: const Text('Counters & status'),
              subtitle: Text(_counterSummary(seat)),
              onTap: () {
                Navigator.of(context).pop();
                showModalBottomSheet<void>(
                  context: context,
                  backgroundColor: PodWiseColors.surfaceRaised,
                  showDragHandle: true,
                  isScrollControlled: true,
                  builder: (_) => CountersSheet(profileId: seat.profileId),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.shield_moon_outlined),
              title: const Text('Commander damage'),
              subtitle: Text(switch (ref
                  .watch(activeGameProvider)
                  ?.damageTakenBy(seat.profileId)) {
                final taken? when taken.isNotEmpty =>
                  '${taken.length} commander'
                      '${taken.length == 1 ? '' : 's'} have connected',
                _ => 'Nothing recorded yet',
              }),
              onTap: () {
                Navigator.of(context).pop();
                _openCommanderDamage(context, seat.profileId);
              },
            ),
            ListTile(
              leading: Icon(
                seat.eliminated
                    ? Icons.replay_rounded
                    : Icons.dangerous_outlined,
                color: seat.eliminated ? null : PodWiseColors.danger,
              ),
              title: Text(
                seat.eliminated
                    ? 'Bring back into the game'
                    : 'Eliminate player',
              ),
              subtitle: seat.eliminated
                  ? null
                  : const Text('Commander has many ways to lose'),
              onTap: () {
                notifier.toggleEliminated(seat.profileId);
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _WinnerDialog extends StatelessWidget {
  const _WinnerDialog({required this.seats});
  final List<Seat> seats;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: PodWiseColors.surfaceRaised,
      // Landscape leaves little height, and this list grows with the player
      // count — six seats plus the draw option will not fit unaided.
      scrollable: true,
      title: const Text('Who won?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final seat in seats)
            ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: PodWiseColors
                    .seats[seat.colorIndex % PodWiseColors.seats.length],
                child: Text(
                  seat.initials,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              title: Text(seat.name),
              onTap: () => Navigator.of(context).pop(seat.profileId),
            ),
          ListTile(
            dense: true,
            leading: const Icon(Icons.help_outline_rounded),
            title: const Text('No winner / draw'),
            onTap: () => Navigator.of(context).pop(''),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
      ],
    );
  }
}

/// Short description of what a player currently has on them, for the sheet.
String _counterSummary(Seat seat) {
  final counters = seat.counters.entries.where((e) => e.value > 0).length;
  final statuses = seat.statuses.length;
  if (counters == 0 && statuses == 0) return 'None';
  return [
    if (counters > 0) '$counters counter${counters == 1 ? '' : 's'}',
    if (statuses > 0) '$statuses status${statuses == 1 ? '' : 'es'}',
  ].join(' · ');
}

/// Commander damage for one player, without going via their detail sheet.
///
/// File-level because two very different places open it — the seat sheet's
/// own row and the long-press shortcut on the panel — and they must not drift
/// apart.
void _openCommanderDamage(BuildContext context, String profileId) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: PodWiseColors.surfaceRaised,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => CommanderDamageSheet(targetProfileId: profileId),
  );
}

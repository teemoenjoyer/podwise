import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../domain/transfer.dart';
import '../../state/providers.dart';
import '../../state/transfer_providers.dart';
import '../transfer/import_pod_screen.dart';
import '../transfer/scan_code_screen.dart';
import '../game/game_screen.dart';
import '../history/history_screen.dart';
import '../pods/pod_builder_screen.dart';
import '../players/players_screen.dart';
import '../settings/settings_screen.dart';
import '../setup/new_game_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeGame = ref.watch(activeGameProvider);
    final history = ref.watch(gameHistoryProvider);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Wordmark(),
              const Spacer(),
              if (activeGame != null && !activeGame.isFinished) ...[
                _ResumeCard(
                  seatCount: activeGame.seats.length,
                  onResume: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const GameScreen()),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const NewGameScreen(),
                  ),
                ),
                child: const Text('NEW GAME'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const PodBuilderScreen(),
                  ),
                ),
                child: const Text('BUILD PODS'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const HistoryScreen(),
                  ),
                ),
                child: Text(switch (history) {
                  AsyncData(:final value) when value.isNotEmpty =>
                    'GAME HISTORY  ·  ${value.length}',
                  _ => 'GAME HISTORY',
                }),
              ),
              const SizedBox(height: 12),
              // One entry for both directions: receiving a pod to keep score
              // for, and taking home the result of one you sent out. Which it
              // is comes from the code itself, so the table never has to pick
              // the right menu item first.
              OutlinedButton.icon(
                onPressed: () => _scan(context, ref),
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 20),
                label: const Text('SCAN A CODE'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const PlayersScreen(),
                        ),
                      ),
                      child: const Text('PLAYERS'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SettingsScreen(),
                        ),
                      ),
                      child: const Text('SETTINGS'),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                'Card data from Scryfall. Unofficial fan project, not '
                'affiliated with Wizards of the Coast.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.5,
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reads a code and does whatever it turns out to be.
Future<void> _scan(BuildContext context, WidgetRef ref) async {
  final payload = await Navigator.of(context).push<TransferPayload>(
    MaterialPageRoute(builder: (_) => const ScanCodeScreen()),
  );
  if (payload == null || !context.mounted) return;

  switch (payload) {
    case PodTransfer():
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ImportPodScreen(pod: payload)),
      );

    case ResultTransfer():
      final outcome = await ref
          .read(transferServiceProvider)
          .importResult(payload);
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(switch (outcome) {
            ImportOutcome.saved =>
              'Result saved. It is in your history and counts towards '
                  'every record it touches.',
            ImportOutcome.alreadyHave =>
              'You already have that result — nothing was changed.',
            ImportOutcome.notOurs =>
              'That result belongs to a pod sent from a different phone.',
          }),
        ),
      );
  }
}

/// Whether the wordmark has already played this launch.
///
/// Home is rebuilt every time you come back from a game, history or settings,
/// and a logo that re-animates on every return stops reading as the app
/// opening and starts reading as a screen that cannot settle down. So it
/// plays once per launch and is simply *there* every time after.
bool _wordmarkPlayed = false;

/// Lets a test start from a fresh launch.
@visibleForTesting
void resetWordmarkAnimation() => _wordmarkPlayed = false;

/// How long to wait after the first frame before the wordmark starts.
///
/// Long enough for the system splash to finish getting out of the way, so the
/// animation happens where somebody can see it.
@visibleForTesting
const wordmarkSettleIn = Duration(milliseconds: 400);
const _settleIn = wordmarkSettleIn;

/// How long to wait for that first frame before starting anyway.
@visibleForTesting
const wordmarkStartBackstop = Duration(seconds: 2);

class _Wordmark extends StatefulWidget {
  const _Wordmark();

  @override
  State<_Wordmark> createState() => _WordmarkState();
}

class _WordmarkState extends State<_Wordmark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    // Long enough to notice, short enough that nobody waits on it — the
    // buttons underneath are live throughout.
    duration: const Duration(milliseconds: 1000),
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    if (_wordmarkPlayed) {
      _controller.value = 1;
      return;
    }
    _wordmarkPlayed = true;

    // Held back until the app is actually on screen, rather than started
    // here. The window stays covered by the system splash while the engine
    // builds and renders — on a slow start that is seconds of real frames —
    // so an animation started in initState runs, and finishes, behind it. The
    // first *rasterized* frame is the point the window has something to show,
    // which is the only signal here that tracks what the eye sees.
    _scheduleStart();
  }

  Timer? _pending;
  bool _begun = false;

  void _scheduleStart() {
    // Whichever comes first. The wordmark begins at zero opacity, so a signal
    // that never arrives would leave the logo invisible for the whole session
    // — far worse than an animation nobody sees. The backstop makes waiting
    // for the frame an optimisation rather than a dependency.
    _pending = Timer(wordmarkStartBackstop, _begin);
    WidgetsBinding.instance.waitUntilFirstFrameRasterized.then((_) {
      if (mounted) _begin();
    });
  }

  void _begin() {
    if (_begun || !mounted) return;
    _begun = true;
    _pending?.cancel();
    // Then a beat for the splash to get out of the way.
    _pending = Timer(_settleIn, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Somebody who has asked the system to reduce motion gets the wordmark
    // already settled rather than a smaller version of the same movement.
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    // Cancelled, so a Home that is left before the animation starts does not
    // leave a timer running against a dead widget.
    _pending?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// [begin] to [end] over the slice of the run between [from] and [to].
  ///
  /// Worked out directly rather than through a CurvedAnimation, which would
  /// mean allocating — and disposing — five of them per frame.
  double _at(double begin, double end, Curve curve, double from, double to) {
    final t = ((_controller.value - from) / (to - from)).clamp(0.0, 1.0);
    return begin + (end - begin) * curve.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // The letters start close together and relax out to their real
        // tracking. On a wordmark this wide that reads as it settling into
        // place, and it needs no extra chrome to do it.
        final titleSpacing = _at(2, 10, Curves.easeOutCubic, 0, 0.75);
        final titleOpacity = _at(0, 1, Curves.easeOut, 0, 0.55);
        final subtitleSpacing = _at(1.5, 4, Curves.easeOutCubic, 0.4, 1);
        final subtitleOpacity = _at(0, 0.4, Curves.easeOut, 0.4, 1);

        return Column(
          children: [
            Opacity(
              opacity: titleOpacity.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, _at(10, 0, Curves.easeOutCubic, 0, 0.75)),
                child: Text(
                  'PODWISE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w200,
                    letterSpacing: titleSpacing,
                    color: PodWiseColors.accent,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'COMMANDER COMPANION',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                letterSpacing: subtitleSpacing,
                color: Colors.white.withValues(
                  alpha: subtitleOpacity.clamp(0.0, 1.0),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.seatCount, required this.onResume});

  final int seatCount;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: PodWiseColors.accent.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onResume,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Icon(
                Icons.play_arrow_rounded,
                color: PodWiseColors.accent,
                size: 28,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RESUME GAME',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        color: PodWiseColors.accent,
                      ),
                    ),
                    Text(
                      '$seatCount players in progress',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

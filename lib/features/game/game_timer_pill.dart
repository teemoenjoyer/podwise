import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../domain/game_timer.dart';
import '../../state/providers.dart';

/// The game clock, shown beside the centre menu.
///
/// Repaints once a second from its own ticker rather than rebuilding the whole
/// board — the life panels have no reason to rebuild sixty times a minute.
class GameTimerPill extends ConsumerStatefulWidget {
  const GameTimerPill({super.key});

  @override
  ConsumerState<GameTimerPill> createState() => _GameTimerPillState();
}

class _GameTimerPillState extends ConsumerState<GameTimerPill> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // The displayed value is derived from the clock, so a missed tick only
    // delays the repaint — it can never make the time wrong.
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final timer = ref.watch(
      activeGameProvider.select((g) => g?.timer ?? const GameTimer()),
    );
    final notifier = ref.read(activeGameProvider.notifier);

    return Material(
      color: timer.isRunning
          ? PodWiseColors.surfaceHigh
          : PodWiseColors.surfaceRaised,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: notifier.toggleTimer,
        onLongPress: notifier.resetTimer,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                timer.isRunning
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                size: 15,
                color: timer.isRunning
                    ? PodWiseColors.accent
                    : Colors.white.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 6),
              Text(
                GameTimer.format(timer.elapsed),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: timer.isRunning
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

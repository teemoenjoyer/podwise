import 'package:flutter/foundation.dart';

/// A stopwatch for the game.
///
/// Stores wall-clock instants rather than a running tally, so the elapsed time
/// stays correct across backgrounding, screen lock and process death — the
/// brief asks for exactly that, and a Timer-driven counter cannot deliver it
/// because Android stops delivering ticks to a backgrounded app.
@immutable
class GameTimer {
  const GameTimer({this.accumulated = Duration.zero, this.runningSince});

  /// Time banked from previous runs, excluding the current one.
  final Duration accumulated;

  /// When the current run began, or null when paused.
  final DateTime? runningSince;

  bool get isRunning => runningSince != null;

  /// Total elapsed time, computed from the clock rather than counted up.
  Duration elapsedAt(DateTime now) => runningSince == null
      ? accumulated
      : accumulated + now.difference(runningSince!);

  Duration get elapsed => elapsedAt(DateTime.now());

  GameTimer start(DateTime now) =>
      isRunning ? this : GameTimer(accumulated: accumulated, runningSince: now);

  GameTimer pause(DateTime now) =>
      isRunning ? GameTimer(accumulated: elapsedAt(now)) : this;

  GameTimer toggle(DateTime now) => isRunning ? pause(now) : start(now);

  GameTimer reset() => const GameTimer();

  /// `01:24:37`, or `24:37` under an hour.
  ///
  /// Hours are dropped below the hour mark because a Commander game is usually
  /// under one, and a leading `00:` is just noise on a table-centre display.
  static String format(Duration d) {
    final negative = d.isNegative;
    final abs = d.abs();
    final hours = abs.inHours;
    final minutes = abs.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = abs.inSeconds.remainder(60).toString().padLeft(2, '0');
    final body = hours > 0
        ? '${hours.toString().padLeft(2, '0')}:$minutes:$seconds'
        : '$minutes:$seconds';
    return negative ? '-$body' : body;
  }
}

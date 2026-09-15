import 'package:flutter_test/flutter_test.dart';
import 'package:podwise/domain/game_timer.dart';

void main() {
  final t0 = DateTime(2026, 9, 14, 12);

  group('running and pausing', () {
    test('a fresh timer is stopped at zero', () {
      const timer = GameTimer();
      expect(timer.isRunning, isFalse);
      expect(timer.elapsedAt(t0), Duration.zero);
    });

    test('counts from the clock while running', () {
      final timer = const GameTimer().start(t0);
      expect(timer.isRunning, isTrue);
      expect(
        timer.elapsedAt(t0.add(const Duration(minutes: 3))),
        const Duration(minutes: 3),
      );
    });

    test('pausing banks the elapsed time and stops counting', () {
      final paused = const GameTimer()
          .start(t0)
          .pause(t0.add(const Duration(minutes: 5)));

      expect(paused.isRunning, isFalse);
      expect(paused.accumulated, const Duration(minutes: 5));
      // An hour later it still reads five minutes.
      expect(
        paused.elapsedAt(t0.add(const Duration(hours: 1))),
        const Duration(minutes: 5),
      );
    });

    test('resuming adds to the banked time rather than restarting', () {
      final resumed = const GameTimer()
          .start(t0)
          .pause(t0.add(const Duration(minutes: 5)))
          .start(t0.add(const Duration(minutes: 10)));

      expect(
        resumed.elapsedAt(t0.add(const Duration(minutes: 12))),
        const Duration(minutes: 7),
        reason: '5 banked plus 2 since resuming',
      );
    });

    test('starting an already-running timer changes nothing', () {
      final running = const GameTimer().start(t0);
      final again = running.start(t0.add(const Duration(minutes: 4)));
      expect(
        again.elapsedAt(t0.add(const Duration(minutes: 6))),
        const Duration(minutes: 6),
        reason: 'the original start instant must be kept',
      );
    });

    test('pausing an already-paused timer changes nothing', () {
      final paused = const GameTimer(accumulated: Duration(minutes: 2));
      expect(paused.pause(t0).accumulated, const Duration(minutes: 2));
    });

    test('reset clears everything', () {
      final reset = const GameTimer().start(t0).reset();
      expect(reset.isRunning, isFalse);
      expect(reset.elapsedAt(t0.add(const Duration(hours: 2))), Duration.zero);
    });

    test('toggle flips between running and paused', () {
      final running = const GameTimer().toggle(t0);
      expect(running.isRunning, isTrue);
      expect(
        running.toggle(t0.add(const Duration(minutes: 1))).isRunning,
        isFalse,
      );
    });
  });

  group('surviving backgrounding', () {
    test('keeps counting across a long gap with no ticks', () {
      // The app gets no timer callbacks while backgrounded, so elapsed time
      // must come from the clock. This is the case a counted-up timer fails.
      final timer = const GameTimer().start(t0);
      final afterBackground = t0.add(const Duration(hours: 1, minutes: 17));

      expect(
        timer.elapsedAt(afterBackground),
        const Duration(hours: 1, minutes: 17),
      );
    });

    test('a paused timer does not advance while backgrounded', () {
      final paused = const GameTimer()
          .start(t0)
          .pause(t0.add(const Duration(minutes: 20)));

      expect(
        paused.elapsedAt(t0.add(const Duration(days: 1))),
        const Duration(minutes: 20),
      );
    });
  });

  group('formatting', () {
    test('drops the hour field below an hour', () {
      expect(
        GameTimer.format(const Duration(minutes: 24, seconds: 37)),
        '24:37',
      );
      expect(GameTimer.format(Duration.zero), '00:00');
    });

    test('shows hours once past the hour mark', () {
      expect(
        GameTimer.format(const Duration(hours: 1, minutes: 24, seconds: 37)),
        '01:24:37',
      );
    });

    test('pads every field', () {
      expect(GameTimer.format(const Duration(minutes: 5, seconds: 4)), '05:04');
      expect(
        GameTimer.format(const Duration(hours: 2, minutes: 3, seconds: 9)),
        '02:03:09',
      );
    });

    test('handles very long games', () {
      expect(
        GameTimer.format(const Duration(hours: 12, minutes: 34, seconds: 56)),
        '12:34:56',
      );
    });
  });
}

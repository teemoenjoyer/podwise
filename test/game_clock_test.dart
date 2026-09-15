import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podwise/data/database.dart';
import 'package:podwise/domain/models.dart';
import 'package:podwise/state/providers.dart';
import 'package:podwise/state/settings_providers.dart';

/// The clock counts from the start of the game whether or not anybody can see
/// it, and it stays off the board unless asked for.
void main() {
  late PodWiseDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = PodWiseDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  void startGame() {
    container
        .read(activeGameProvider.notifier)
        .start(
          startingLife: 40,
          players: const [
            PlayerProfile(id: 'a', name: 'Ana'),
            PlayerProfile(id: 'b', name: 'Ben'),
          ],
        );
  }

  test('it is already running when the game begins', () {
    startGame();
    final game = container.read(activeGameProvider)!;

    // Nobody should have to remember to start a stopwatch.
    expect(game.timer.isRunning, isTrue);
    expect(game.timer.runningSince, isNotNull);
  });

  test('it counts from the moment the game started', () {
    startGame();
    final game = container.read(activeGameProvider)!;

    // Stored as an instant rather than a tally, so it stays honest across
    // the app being backgrounded.
    expect(
      game.timer.runningSince!.difference(game.startedAt).inMilliseconds.abs(),
      lessThan(50),
    );
    expect(
      game.timer
          .elapsedAt(game.startedAt.add(const Duration(minutes: 7)))
          .inMinutes,
      7,
    );
  });

  test('it can still be paused by hand', () {
    startGame();
    container.read(activeGameProvider.notifier).toggleTimer();

    expect(container.read(activeGameProvider)!.timer.isRunning, isFalse);
  });

  group('the first-turn draw is asked once', () {
    test('accepting it records who goes first', () {
      startGame();
      container.read(activeGameProvider.notifier).recordFirstPlayerDraw('b');

      final game = container.read(activeGameProvider)!;
      expect(game.firstPlayerId, 'b');
      expect(game.firstPlayerAsked, isTrue);
    });

    test('skipping it still counts as answered', () {
      startGame();
      container.read(activeGameProvider.notifier).recordFirstPlayerDraw(null);

      final game = container.read(activeGameProvider)!;
      // Nobody was drawn, but the table has been asked — leaving the board and
      // coming back should not put the question up again.
      expect(game.firstPlayerId, isNull);
      expect(game.firstPlayerAsked, isTrue);
    });

    test('a new game asks again', () {
      startGame();
      container.read(activeGameProvider.notifier).recordFirstPlayerDraw(null);
      startGame();

      expect(container.read(activeGameProvider)!.firstPlayerAsked, isFalse);
    });
  });

  group('staying off the board', () {
    test('a fresh install does not show it', () async {
      final settings = await container.read(settingsProvider.future);
      expect(settings.showTimer, isFalse);
    });

    test('an install that had it on is moved across, once', () async {
      // What an install made before this change looks like.
      await db.putSetting(AppSettings.timerKey, 'true');

      expect(
        (await container.read(settingsProvider.future)).showTimer,
        isFalse,
        reason: 'changing a default alone never reaches existing installs',
      );

      // Turning it back on must stick rather than being moved again.
      await container.read(settingsProvider.notifier).setShowTimer(true);
      container.invalidate(settingsProvider);
      expect((await container.read(settingsProvider.future)).showTimer, isTrue);
    });
  });
}

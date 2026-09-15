import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podwise/data/database.dart';
import 'package:podwise/domain/models.dart';
import 'package:podwise/domain/transfer.dart';
import 'package:podwise/state/providers.dart';
import 'package:podwise/state/transfer_providers.dart';

/// The two ends of a pod handed to another phone: that a borrowed game never
/// lands in this phone's history, and that a result coming home lands there
/// exactly once.
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

  TransferService service() => container.read(transferServiceProvider);
  Future<String> deviceId() => container.read(transferDeviceIdProvider.future);

  group('device identity', () {
    test('is generated once and then kept', () async {
      final first = await deviceId();
      expect(first, isNotEmpty);

      container.invalidate(transferDeviceIdProvider);
      expect(await deviceId(), first);
    });
  });

  group('a borrowed game stays off this phone', () {
    test('finishing one writes nothing to history', () async {
      container
          .read(activeGameProvider.notifier)
          .start(
            startingLife: 40,
            borrowedFrom: 'some-other-phone',
            players: const [
              PlayerProfile(id: 'x', name: 'Stranger One'),
              PlayerProfile(id: 'y', name: 'Stranger Two'),
            ],
          );

      await container
          .read(activeGameProvider.notifier)
          .finish(winnerProfileId: 'x');

      // The people in a borrowed pod belong to someone else's playgroup.
      // Recording them here would put them in these statistics for good.
      expect(await db.recentGames(), isEmpty);
      expect(await db.playerStatistics(), isEmpty);
      expect(await db.deckRecords(), isEmpty);
    });

    test('the game is still marked finished, so a code can be made', () async {
      container
          .read(activeGameProvider.notifier)
          .start(
            startingLife: 40,
            borrowedFrom: 'some-other-phone',
            players: const [
              PlayerProfile(id: 'x', name: 'Stranger One'),
              PlayerProfile(id: 'y', name: 'Stranger Two'),
            ],
          );
      await container
          .read(activeGameProvider.notifier)
          .finish(winnerProfileId: 'y');

      final game = container.read(activeGameProvider)!;
      expect(game.isFinished, isTrue);
      expect(game.winnerProfileId, 'y');

      final packed = service().packResult(game);
      expect(packed.sourceDeviceId, 'some-other-phone');
      expect(packed.winnerPlayerId, 'y');
      expect(packed.results.first.playerId, 'y');
      expect(packed.results.first.position, 1);
    });

    test('a normal game is unaffected and still saves', () async {
      container
          .read(activeGameProvider.notifier)
          .start(
            startingLife: 40,
            players: const [
              PlayerProfile(id: 'x', name: 'Ours One'),
              PlayerProfile(id: 'y', name: 'Ours Two'),
            ],
          );
      await container
          .read(activeGameProvider.notifier)
          .finish(winnerProfileId: 'x');

      expect(await db.recentGames(), hasLength(1));
    });
  });

  group('surviving the phone being killed', () {
    // A borrowed pod is the one game nobody else has a copy of. If the
    // receiving phone drops it, the result is gone and the sender never finds
    // out — so it is written down as it goes.
    Future<void> startBorrowed() async {
      container
          .read(activeGameProvider.notifier)
          .start(
            startingLife: 40,
            borrowedFrom: 'other-phone',
            gameId: 'borrowed-1',
            players: const [
              PlayerProfile(id: 'x', name: 'Stranger One', colorIndex: 2),
              PlayerProfile(id: 'y', name: 'Stranger Two', colorIndex: 3),
            ],
          );
      // The write is debounced, so let it land.
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }

    test('a borrowed game in progress is written down', () async {
      await startBorrowed();
      container.read(activeGameProvider.notifier).adjustLife('x', -7);
      await Future<void>.delayed(const Duration(milliseconds: 600));

      final stored = (await db.allSettings())['borrowedGame'];
      expect(stored, isNotNull);
      expect(stored, isNotEmpty);
    });

    test('it comes back with the scoreboard intact', () async {
      await startBorrowed();
      final notifier = container.read(activeGameProvider.notifier);
      notifier.adjustLife('x', -7);
      notifier.adjustCounter('y', 'poison', 3);
      notifier.toggleEliminated('y');
      await Future<void>.delayed(const Duration(milliseconds: 600));

      // Stand in for the process being killed: a fresh container over the
      // same database, with nothing in memory.
      final reborn = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(reborn.dispose);
      reborn.read(activeGameProvider);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      final restored = reborn.read(activeGameProvider);
      expect(restored, isNotNull);
      expect(restored!.id, 'borrowed-1');
      expect(restored.borrowedFrom, 'other-phone');
      expect(restored.seats.firstWhere((s) => s.profileId == 'x').life, 33);
      expect(
        restored.seats.firstWhere((s) => s.profileId == 'y').counters['poison'],
        3,
      );
      expect(
        restored.seats.firstWhere((s) => s.profileId == 'y').eliminated,
        isTrue,
      );
    });

    test('a finished borrowed game is kept so its code can be shown again', () async {
      await startBorrowed();
      await container
          .read(activeGameProvider.notifier)
          .finish(winnerProfileId: 'x');
      await Future<void>.delayed(const Duration(milliseconds: 600));

      final reborn = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(reborn.dispose);
      reborn.read(activeGameProvider);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      // The code on the result screen is the only copy of this result, and the
      // phone showing it may well be backgrounded before anyone scans it.
      final restored = reborn.read(activeGameProvider);
      expect(restored?.isFinished, isTrue);
      expect(restored?.winnerProfileId, 'x');
    });

    test('discarding it clears the saved copy', () async {
      await startBorrowed();
      container.read(activeGameProvider.notifier).clear();
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect((await db.allSettings())['borrowedGame'], isEmpty);
    });

    test('a game this phone owns is not written down mid-play', () async {
      container
          .read(activeGameProvider.notifier)
          .start(
            startingLife: 40,
            players: const [
              PlayerProfile(id: 'a', name: 'Ours'),
              PlayerProfile(id: 'b', name: 'Also ours'),
            ],
          );
      await Future<void>.delayed(const Duration(milliseconds: 600));

      // Only borrowed pods need this; our own games already have an owner
      // watching them, and history is written when they finish.
      expect((await db.allSettings())['borrowedGame'], isNull);
    });
  });

  group('a result coming home', () {
    test('is written to history with its decks intact', () async {
      final outcome = await service().importResult(
        await _result(deviceId: await deviceId()),
      );

      expect(outcome, ImportOutcome.saved);

      final games = await db.recentGames();
      expect(games, hasLength(1));
      expect(games.single.winnerProfileId, 'dave');

      final records = await db.deckRecords();
      expect(records['atraxa'], (games: 1, wins: 1));
      expect(records['krenko'], (games: 1, wins: 0));
    });

    test('seats are stored as they sat, not as they finished', () async {
      await service().importResult(await _result(deviceId: await deviceId()));

      final participants = await db.participantsOf('game-1');
      // participantsOf orders by seat index, so this is the table order.
      expect(participants.map((p) => p.name), ['Ben', 'Dave']);
      expect(participants.map((p) => p.position), [2, 1]);
    });

    test('importing the same result twice does not double anybody', () async {
      final result = await _result(deviceId: await deviceId());

      expect(await service().importResult(result), ImportOutcome.saved);
      expect(await service().importResult(result), ImportOutcome.alreadyHave);

      expect(await db.recentGames(), hasLength(1));
      // The participants are the real risk: the game upserts, but its
      // participants would insert a second time against an autoincrement key
      // and quietly double every record.
      expect(await db.participantsOf('game-1'), hasLength(2));
      expect((await db.deckRecords())['atraxa'], (games: 1, wins: 1));
    });

    test('a result from a pod we never sent is refused', () async {
      final outcome = await service().importResult(
        await _result(deviceId: 'a-completely-different-phone'),
      );

      // Otherwise a stranger's players end up in these statistics with nothing
      // to ever remove them.
      expect(outcome, ImportOutcome.notOurs);
      expect(await db.recentGames(), isEmpty);
    });

    test('a game nobody won is recorded as having no winner', () async {
      await service().importResult(
        await _result(deviceId: await deviceId(), winner: null),
      );

      final games = await db.recentGames();
      expect(games.single.winnerProfileId, isNull);
      // Position 1 still exists — somebody has to be listed first — but it
      // must not be promoted into a win.
      expect((await db.deckRecords())['atraxa'], (games: 1, wins: 1));
    });

    test(
      'a player with no deck does not create an empty-string deck',
      () async {
        await service().importResult(
          await _result(deviceId: await deviceId(), deckless: true),
        );

        final records = await db.deckRecords();
        expect(records.containsKey(''), isFalse);
        expect(records.keys, ['atraxa']);
      },
    );
  });
}

Future<ResultTransfer> _result({
  required String deviceId,
  String? winner = 'dave',
  bool deckless = false,
}) async => ResultTransfer(
  sourceDeviceId: deviceId,
  gameId: 'game-1',
  startedAt: DateTime(2026, 9, 13, 19),
  finishedAt: DateTime(2026, 9, 13, 20),
  startingLife: 40,
  winnerPlayerId: winner,
  results: [
    const TransferResult(
      playerId: 'dave',
      name: 'Dave',
      colorIndex: 2,
      seatIndex: 1,
      position: 1,
      finalLife: 31,
      deckId: 'atraxa',
    ),
    TransferResult(
      playerId: 'ben',
      name: 'Ben',
      colorIndex: 0,
      seatIndex: 0,
      position: 2,
      finalLife: 0,
      deckId: deckless ? null : 'krenko',
      eliminated: true,
    ),
  ],
);

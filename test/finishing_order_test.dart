import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podwise/data/database.dart';
import 'package:podwise/domain/models.dart';
import 'package:podwise/state/providers.dart';

/// Finishing position comes from the order people were knocked out, never from
/// what life they had left.
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

  ActiveGameNotifier notifier() => container.read(activeGameProvider.notifier);
  GameState game() => container.read(activeGameProvider)!;

  /// Knocks a player out and lets the automatic win settle.
  ///
  /// Ending the game writes it to the database, so the last knockout of a game
  /// takes effect a beat later rather than synchronously.
  Future<void> eliminate(String id) async {
    notifier().toggleEliminated(id);
    await Future<void>.delayed(const Duration(milliseconds: 30));
  }

  void startGame(int players) {
    notifier().start(
      startingLife: 40,
      players: [
        for (var i = 0; i < players; i++)
          PlayerProfile(id: 'p$i', name: 'P$i', colorIndex: i),
      ],
    );
  }

  group('finishing order', () {
    test('the first player out finishes last', () async {
      startGame(4);
      await eliminate('p1'); // out first
      await eliminate('p3'); // out second
      await eliminate('p0'); // out third — leaves p2 alone

      // p2 is the sole survivor, so the game has settled itself.
      final ranked = game().rankedBy(game().winnerProfileId);
      expect(ranked.map((s) => s.profileId), ['p2', 'p0', 'p3', 'p1']);
    });

    test('life totals do not decide it', () async {
      startGame(4);

      // The first player out is on the highest life of anyone: knocked out by
      // commander damage, or by an effect, with plenty left in the tank.
      notifier().setLife('p1', 38);
      notifier().setLife('p3', 25);
      notifier().setLife('p0', 3);
      notifier().setLife('p2', 1);

      await eliminate('p1');
      await eliminate('p3');
      await eliminate('p0');

      final ranked = game().rankedBy(game().winnerProfileId);
      // Ranked by life, p1 would have come second. They went out first, so
      // they are last.
      expect(ranked.map((s) => s.profileId), ['p2', 'p0', 'p3', 'p1']);
      expect(ranked.last.life, 38);
    });

    test('players still standing rank above anyone knocked out', () async {
      startGame(4);
      await eliminate('p0');

      // Ended early with three alive, and p3 declared the winner.
      final ranked = game().rankedBy('p3');
      expect(ranked.first.profileId, 'p3');
      expect(ranked.last.profileId, 'p0');
      // The other two survivors keep their seat order.
      expect(ranked[1].profileId, 'p1');
      expect(ranked[2].profileId, 'p2');
    });

    test('an explicit winner leads even if they were knocked out', () async {
      startGame(3);
      await eliminate('p0');

      // Odd, but it is the table's call and the app should not argue.
      final ranked = game().rankedBy('p0');
      expect(ranked.first.profileId, 'p0');
    });

    test('the order is the same every time it is asked for', () async {
      startGame(6);
      for (final id in ['p4', 'p0', 'p2']) {
        notifier().toggleEliminated(id);
      }

      final once = game().rankedBy('p1').map((s) => s.profileId).toList();
      final twice = game().rankedBy('p1').map((s) => s.profileId).toList();
      expect(once, twice);
    });
  });

  group('the last one standing wins', () {
    test('knocking out the second-to-last player ends the game', () async {
      startGame(4);
      await eliminate('p0');
      await eliminate('p1');
      expect(game().isFinished, isFalse, reason: 'two players still in it');

      await eliminate('p2');
      // Nobody should have to go and find the menu to say the obvious.
      expect(game().isFinished, isTrue);
      expect(game().winnerProfileId, 'p3');

      final saved = await db.recentGames();
      expect(saved, hasLength(1));
      expect(saved.single.winnerProfileId, 'p3');
    });

    test('the saved positions follow the knockouts', () async {
      startGame(4);
      await eliminate('p2');
      await eliminate('p0');
      await eliminate('p3');
      final games = await db.recentGames();
      final participants = await db.participantsOf(games.single.id);
      final byPosition = {
        for (final p in participants) p.position: p.profileId,
      };

      expect(byPosition[1], 'p1'); // survivor
      expect(byPosition[2], 'p3'); // out last
      expect(byPosition[3], 'p0');
      expect(byPosition[4], 'p2'); // out first
    });

    test('a two-player game ends on the first knockout', () async {
      startGame(2);
      await eliminate('p0');

      expect(game().isFinished, isTrue);
      expect(game().winnerProfileId, 'p1');
    });

    test('reviving somebody does not end it', () async {
      startGame(3);
      await eliminate('p0');
      await eliminate('p0'); // put back in

      expect(game().isFinished, isFalse);
      expect(game().seats.where((s) => s.eliminated), isEmpty);
    });

    test(
      'reviving somebody does not muddle the order of later exits',
      () async {
        startGame(5);
        await eliminate('p0'); // out first
        await eliminate('p1'); // out second
        await eliminate('p0'); // back in
        await eliminate('p2'); // out third

        final orders = {
          for (final s in game().seats)
            if (s.eliminationOrder != null) s.profileId: s.eliminationOrder,
        };

        // Counting who is currently out would have handed p2 the number p1
        // already had, leaving them tied for the same finishing place.
        expect(orders['p1'], isNot(orders['p2']));
        expect(orders['p2']! > orders['p1']!, isTrue);

        final ranked = game().rankedBy('p3');
        expect(ranked.map((s) => s.profileId).toList().sublist(3), [
          'p2',
          'p1',
        ]);
      },
    );

    test('a finished game ignores further elimination taps', () async {
      startGame(2);
      await eliminate('p0');
      expect(game().isFinished, isTrue);

      // The board is on its way out; a late tap must not rewrite the result.
      await eliminate('p1');
      expect(game().winnerProfileId, 'p1');
      expect(
        game().seats.firstWhere((s) => s.profileId == 'p1').eliminated,
        isFalse,
      );
    });
  });
}

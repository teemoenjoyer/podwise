import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podwise/core/theme.dart';
import 'package:podwise/data/database.dart';
import 'package:podwise/domain/counters.dart';
import 'package:podwise/domain/models.dart';
import 'package:podwise/domain/seating.dart';
import 'package:podwise/features/game/game_screen.dart';
import 'package:podwise/state/providers.dart';

/// A Pixel 10a lying flat on the table: landscape, and short on height.
///
/// Every overlay on the game screen competes for this limited vertical space,
/// which is where the overflow bugs come from.
const _landscape = Size(2424, 1080);

/// 420dpi / 160 — the device's real density.
///
/// This matters more than it looks: at a ratio of 1.0 the test window would be
/// 2424x1080 *logical* pixels, which is roomy enough that nothing ever
/// overflows and these tests would pass against broken layouts. The real
/// device has only ~923x411 logical pixels to work with.
const _devicePixelRatio = 2.625;

/// The container each pumped game is running in, so a test can drive the
/// notifier directly.
final _containers = <WidgetTester, ProviderContainer>{};

ProviderContainer container(WidgetTester tester) => _containers[tester]!;

void main() {
  late PodWiseDatabase db;

  setUp(() {
    db = PodWiseDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> pumpGame(
    WidgetTester tester,
    int playerCount, {

    /// The board offers the first-turn draw the moment it opens. These tests
    /// are about everything behind it, so by default the draw is treated as
    /// already settled.
    bool drawFirstPlayer = false,
  }) async {
    tester.view
      ..physicalSize = _landscape
      ..devicePixelRatio = _devicePixelRatio;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);
    _containers[tester] = container;

    container
        .read(activeGameProvider.notifier)
        .start(
          startingLife: 40,
          players: [
            for (var i = 0; i < playerCount; i++)
              PlayerProfile(
                id: 'p$i',
                // A long name is the stressing case for panel width.
                name: 'Player Longname $i',
                colorIndex: i,
              ),
          ],
        );

    if (!drawFirstPlayer) {
      container.read(activeGameProvider.notifier).recordFirstPlayerDraw('p0');
    }

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildPodWiseTheme(),
          home: const GameScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  // Every seat count uses a different row split, so each is worth covering.
  for (final playerCount in [2, 3, 4, 5, 6, 7, 8, 9, 10]) {
    testWidgets('$playerCount-player board lays out without overflow', (
      tester,
    ) async {
      await pumpGame(tester, playerCount);

      expect(tester.takeException(), isNull);
      expect(find.byType(GameScreen), findsOneWidget);
      // Every seat gets a visible life total.
      expect(find.text('40'), findsNWidgets(playerCount));
    });
  }

  testWidgets('the first-turn draw fits in landscape at six players', (
    tester,
  ) async {
    await pumpGame(tester, 6, drawFirstPlayer: true);

    // It opens asking, not rolling.
    expect(tester.takeException(), isNull);
    expect(find.text('Roll for who goes first?'), findsOneWidget);
    expect(find.text('SKIP'), findsOneWidget);
    expect(find.text('ROLL'), findsOneWidget);
    expect(find.text('START'), findsNothing);

    await tester.tap(find.text('ROLL'));
    // Long enough to cover the roll with room to spare.
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();

    // Six wrapped names plus three buttons is the most this dialog ever has to
    // fit, over a landscape board with ~411 logical pixels of height.
    expect(tester.takeException(), isNull);
    expect(find.text('START'), findsOneWidget);
    expect(find.textContaining('goes first'), findsOneWidget);

    // The reveal must be *visible*, not merely present. Asserting the text
    // exists passed happily while it was clipped under the fold, which is how
    // this got as far as the emulator.
    final scrollable = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(Scrollable),
    );
    expect(
      tester
              .widget<Scrollable>(scrollable)
              .controller
              ?.position
              .maxScrollExtent ??
          Scrollable.of(tester.element(scrollable)).position.maxScrollExtent,
      0,
      reason: 'the draw dialog has content hidden below the fold',
    );
  });

  testWidgets('the draw is not offered once it has been made', (tester) async {
    await pumpGame(tester, 4);

    expect(find.text('Who goes first?'), findsNothing);
  });

  testWidgets('the elimination prompt says why it is asking', (tester) async {
    await pumpGame(tester, 4);

    // Poison, not life: the headline has to explain itself or "is at 40 life"
    // reads like the app asking at random.
    container(tester)
        .read(activeGameProvider.notifier)
        .adjustCounter('p0', CounterPresets.poison.id, 10);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('40 life'), findsOneWidget);
    expect(find.textContaining('10 poison'), findsOneWidget);
    expect(find.text('ELIMINATE'), findsOneWidget);
  });

  testWidgets('the prompt names lethal commander damage', (tester) async {
    await pumpGame(tester, 4);
    final game = container(tester).read(activeGameProvider)!;
    final source = game.seats[1].damageSources.single;

    container(tester)
        .read(activeGameProvider.notifier)
        .adjustCommanderDamage(
          sourceCardId: source.id,
          targetProfileId: 'p0',
          delta: commanderDamageThreshold,
        );
    await tester.pumpAndSettle();

    // Twenty-one from forty leaves nineteen life, so nothing else would have
    // raised this.
    expect(find.textContaining('19 life'), findsOneWidget);
    expect(find.textContaining('21 commander damage'), findsOneWidget);
    expect(find.textContaining(source.name), findsOneWidget);
  });

  testWidgets('the commander damage badge clears the menu button', (
    tester,
  ) async {
    // Two players means two full-width panels, so their centre line is
    // exactly where the menu button sits.
    await pumpGame(tester, 2);
    final game = container(tester).read(activeGameProvider)!;

    container(tester)
        .read(activeGameProvider.notifier)
        .adjustCommanderDamage(
          sourceCardId: game.seats[1].damageSources.single.id,
          targetProfileId: 'p0',
          delta: 12,
        );
    await tester.pumpAndSettle();

    final badge = find.textContaining('12/$commanderDamageThreshold');
    expect(badge, findsOneWidget);

    // Overlapping rectangles, not just "both exist" — the badge was visible
    // the whole time it was hidden behind the button.
    final button = tester.getRect(find.byIcon(Icons.more_horiz_rounded));
    expect(
      tester.getRect(badge).overlaps(button),
      isFalse,
      reason: 'the badge is underneath the menu button',
    );
  });

  testWidgets('with room to spare the badge stays facing the table', (
    tester,
  ) async {
    // Four players means half-width panels, whose centres fall clear of the
    // button, so the badge keeps its spot where opponents can read it.
    await pumpGame(tester, 4);
    final game = container(tester).read(activeGameProvider)!;

    // p2 sits in the near row, which is not rotated, so "towards the middle
    // of the table" really is up the screen.
    container(tester)
        .read(activeGameProvider.notifier)
        .adjustCommanderDamage(
          sourceCardId: game.seats[0].damageSources.single.id,
          targetProfileId: 'p2',
          delta: 12,
        );
    await tester.pumpAndSettle();

    final badge = find.textContaining('12/$commanderDamageThreshold');
    final name = find.text('PLAYER LONGNAME 2');
    // At the table-facing edge, well clear of the name.
    expect(
      tester.getRect(badge).center.dy,
      lessThan(tester.getRect(name).center.dy - 40),
    );
  });

  testWidgets('a game ending from inside a sheet still leaves the board', (
    tester,
  ) async {
    await pumpGame(tester, 2);

    // Poison is applied from the counters sheet, so that sheet is still on the
    // stack when the last opponent goes out. Replacing the *sheet* left the
    // board alive underneath, holding the screen in landscape.
    await tester.tap(find.text('PLAYER LONGNAME 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Counters & status'));
    await tester.pumpAndSettle();

    container(tester)
        .read(activeGameProvider.notifier)
        .adjustCounter('p1', CounterPresets.poison.id, 10);
    await tester.pumpAndSettle();

    await tester.tap(find.text('ELIMINATE'));
    await tester.pumpAndSettle();

    // p0 is the last one standing, so the game settles itself.
    expect(find.text('GAME OVER'), findsOneWidget);
    // The board must be gone, or its dispose never runs and the display stays
    // locked to landscape.
    expect(find.byType(GameScreen), findsNothing);
  });

  testWidgets('the dice sheet fits in landscape', (tester) async {
    await pumpGame(tester, 6);

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Roll dice'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('d20'), findsWidgets);
    expect(find.text('ROLL d20'), findsOneWidget);
  });

  testWidgets('in-game menu fits in landscape at six players', (tester) async {
    await pumpGame(tester, 6);

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('End game'), findsOneWidget);
    expect(find.text('Abandon game'), findsOneWidget);
  });

  testWidgets('winner dialog fits in landscape at six players', (tester) async {
    await pumpGame(tester, 6);

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('End game'));
    await tester.pumpAndSettle();

    // This is the case that overflowed by 121px at four players before the
    // dialog was made scrollable.
    expect(tester.takeException(), isNull);
    expect(find.text('Who won?'), findsOneWidget);
    expect(find.text('No winner / draw'), findsOneWidget);
  });

  testWidgets('player detail sheet fits in landscape', (tester) async {
    await pumpGame(tester, 6);

    await tester.tap(find.text('40').first);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Eliminate player'), findsOneWidget);
  });

  testWidgets('counters sheet fits in landscape', (tester) async {
    await pumpGame(tester, 6);

    await tester.tap(find.text('40').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Counters & status'));
    await tester.pumpAndSettle();

    // This sheet is the tallest in the app — five status chips, eight counter
    // chips, and a stepper row per active counter.
    expect(tester.takeException(), isNull);
    expect(find.text('Monarch'), findsOneWidget);
    expect(find.text('Poison'), findsOneWidget);
  });

  testWidgets('commander damage sheet fits in landscape', (tester) async {
    await pumpGame(tester, 6);

    await tester.tap(find.text('40').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Commander damage'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('ELIMINATED clears the menu button on a full-width panel', (
    tester,
  ) async {
    // Three players, not two: at two, knocking one out ends the game and
    // there is no board left to measure. Three splits 1 + 2, so seat 0 still
    // gets a full-width row whose centre line is under the menu button.
    await pumpGame(tester, 3);
    container(tester).read(activeGameProvider.notifier).toggleEliminated('p0');
    await tester.pumpAndSettle();

    final label = find.text('ELIMINATED');
    expect(label, findsOneWidget);

    final button = tester.getRect(find.byIcon(Icons.more_horiz_rounded));
    expect(
      tester.getRect(label).overlaps(button),
      isFalse,
      reason: 'ELIMINATED is underneath the menu button',
    );
  });

  testWidgets('the pending change clears the menu button too', (tester) async {
    await pumpGame(tester, 2);
    // Mid-tap-window: the running total is the feedback that makes the
    // batching window usable, so hiding it is worse than hiding the badge.
    container(tester).read(activeGameProvider.notifier).adjustLife('p0', -5);
    await tester.pump();

    final pill = find.text('-5');
    expect(pill, findsOneWidget);

    final button = tester.getRect(find.byIcon(Icons.more_horiz_rounded));
    expect(
      tester.getRect(pill).overlaps(button),
      isFalse,
      reason: 'the pending total is underneath the menu button',
    );

    // Let the batching window close, so the commit timer does not outlive
    // the test.
    await tester.pump(pendingCommitDelay);
  });

  testWidgets('with room to spare ELIMINATED stays facing the table', (
    tester,
  ) async {
    // Four players means half-width panels, so it keeps its table-facing spot
    // where opponents can see who is out.
    await pumpGame(tester, 4);
    container(tester).read(activeGameProvider.notifier).toggleEliminated('p2');
    await tester.pumpAndSettle();

    // p2 sits in the near row, which is not rotated.
    expect(
      tester.getRect(find.text('ELIMINATED')).center.dy,
      lessThan(tester.getRect(find.text('PLAYER LONGNAME 2')).center.dy - 40),
    );
  });

  testWidgets('long-pressing a panel goes straight to commander damage', (
    tester,
  ) async {
    await pumpGame(tester, 4);

    await tester.longPress(find.text('PLAYER LONGNAME 2'));
    await tester.pumpAndSettle();

    // Straight there, without the detail sheet in between.
    expect(find.textContaining('Commander damage to'), findsOneWidget);
    expect(find.textContaining('Player Longname 2'), findsWidgets);
  });

  testWidgets('long-pressing the life number does not change life', (
    tester,
  ) async {
    await pumpGame(tester, 4);
    final before = container(tester).read(activeGameProvider)!.seats[2].life;

    await tester.longPress(find.text('PLAYER LONGNAME 2'));
    await tester.pumpAndSettle();

    // The +/- zones either side keep their own long-press for ten at a time;
    // the middle must not quietly do both.
    expect(container(tester).read(activeGameProvider)!.seats[2].life, before);
  });

  testWidgets('seating rearranges the board without moving anybody', (
    tester,
  ) async {
    await pumpGame(tester, 4);
    final notifier = container(tester).read(activeGameProvider.notifier);

    final before = [
      for (var i = 0; i < 4; i++)
        container(tester).read(activeGameProvider)!.seats[i].name,
    ];

    notifier.setSeating(1);
    await tester.pumpAndSettle();

    // Seats keep their order, so nobody's life total slides out from under
    // their finger — only which row the panels are dealt into changes.
    expect(
      [
        for (var i = 0; i < 4; i++)
          container(tester).read(activeGameProvider)!.seats[i].name,
      ],
      before,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('everybody on one side still renders every panel', (
    tester,
  ) async {
    await pumpGame(tester, 4);
    container(tester).read(activeGameProvider.notifier).setSeating(0);
    await tester.pumpAndSettle();

    for (var i = 0; i < 4; i++) {
      expect(find.text('PLAYER LONGNAME $i'), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });


  testWidgets('the seating menu draws a panel for every player', (
    tester,
  ) async {
    await pumpGame(tester, 4);

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seating'));
    await tester.pumpAndSettle();

    // One tile per distinct arrangement.
    for (final far in Seating.optionsFor(4)) {
      expect(
        find.bySemanticsLabel(Seating.describe(4, far)),
        findsOneWidget,
        reason: 'no tile for $far on the far side',
      );
    }

    // And each tile actually draws four panels. An empty DecoratedBox has no
    // height of its own, so the diagram rendered as a blank outline while
    // every widget it needed was present — existence checks alone passed.
    final blocks = find.descendant(
      of: find.bySemanticsLabel(Seating.describe(4, 2)),
      matching: find.byType(DecoratedBox),
    );
    // Five, not four: the first is the tile's own outline, the rest are the
    // panels drawn inside it.
    expect(blocks, findsNWidgets(5));
    for (var i = 1; i < 5; i++) {
      final size = tester.getSize(blocks.at(i));
      expect(size.width, greaterThan(0));
      expect(size.height, greaterThan(0), reason: 'panel $i has no height');
    }
  });

  testWidgets('the seating menu fits in landscape at ten players', (
    tester,
  ) async {
    // Ten players is ten arrangements, in a sheet on a landscape board — the
    // tightest this screen ever gets.
    await pumpGame(tester, 10);

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seating'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });


  testWidgets('swapping two seats takes their life totals with them', (
    tester,
  ) async {
    await pumpGame(tester, 4);
    final notifier = container(tester).read(activeGameProvider.notifier);

    // Give two players distinguishable state first.
    notifier.setLife('p0', 31);
    notifier.setLife('p3', 17);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seating'));
    await tester.pumpAndSettle();

    // Tap one player, then the other.
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Player Longname 0,')));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Player Longname 3,')));
    await tester.pumpAndSettle();

    final seats = container(tester).read(activeGameProvider)!.seats;
    expect(seats[0].name, 'Player Longname 3');
    expect(seats[3].name, 'Player Longname 0');

    // The point of the whole exercise: a player carries their totals to the
    // new chair rather than inheriting whatever was sitting there.
    expect(seats[0].life, 17);
    expect(seats[3].life, 31);
  });

  testWidgets('a swap keeps commander damage with the player', (tester) async {
    await pumpGame(tester, 4);
    final game = container(tester).read(activeGameProvider)!;
    final notifier = container(tester).read(activeGameProvider.notifier);

    notifier.adjustCommanderDamage(
      sourceCardId: game.seats[1].damageSources.single.id,
      targetProfileId: 'p0',
      delta: 9,
    );
    await tester.pumpAndSettle();

    notifier.swapSeats(0, 3);
    await tester.pumpAndSettle();

    // Damage is keyed by player id, not seat, so moving chairs must not
    // hand somebody else's damage to whoever sat down there.
    final after = container(tester).read(activeGameProvider)!;
    expect(after.damageTakenBy('p0').single.value, 9);
    expect(after.damageTakenBy('p3'), isEmpty);
  });

  testWidgets('shuffling up moves everybody round one seat', (tester) async {
    await pumpGame(tester, 4);
    final before = [
      for (final s in container(tester).read(activeGameProvider)!.seats) s.name,
    ];

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Seating'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SHUFFLE UP'));
    await tester.pumpAndSettle();

    final after = [
      for (final s in container(tester).read(activeGameProvider)!.seats) s.name,
    ];
    expect(after, [...before.skip(1), before.first]);
  });


  testWidgets('six down one side lays out without overflow', (tester) async {
    // The reported break: everybody on one side of the phone leaves each seat
    // about 150 pixels, and the minus/number/plus row needs more than that.
    await pumpGame(tester, 6);
    container(tester).read(activeGameProvider.notifier).setSeating(0);
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    for (var i = 0; i < 6; i++) {
      expect(find.text('PLAYER LONGNAME $i'), findsOneWidget);
    }
  });

  testWidgets('every arrangement of every table size fits', (tester) async {
    // Seating made far more layouts reachable than the nine the fixed table
    // used to produce, and only one of them was ever looked at.
    for (var players = 2; players <= 10; players++) {
      await pumpGame(tester, players);
      for (final far in Seating.optionsFor(players)) {
        container(tester).read(activeGameProvider.notifier).setSeating(far);
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '$players players with $far on the far side overflows',
        );
      }
    }
  });

  testWidgets('a narrow panel keeps its life total and both tap targets', (
    tester,
  ) async {
    await pumpGame(tester, 6);
    container(tester).read(activeGameProvider.notifier).setSeating(0);
    await tester.pumpAndSettle();

    // Stacking is only worth doing if it keeps what the panel is for: a
    // readable number and two honest targets either side of nothing.
    expect(find.text('40'), findsNWidgets(6));
    expect(find.text('−'), findsNWidgets(6));
    expect(find.text('+'), findsNWidgets(6));
  });

  testWidgets('a narrow panel puts the name above the life total', (
    tester,
  ) async {
    await pumpGame(tester, 6);
    container(tester).read(activeGameProvider.notifier).setSeating(0);
    await tester.pumpAndSettle();

    // Seat 0 is in the only row, so it is not rotated and "above" on screen
    // really is above.
    final name = tester.getRect(find.text('PLAYER LONGNAME 0'));
    final life = tester.getRect(find.text('40').first);
    expect(name.center.dy, lessThan(life.center.dy));
  });

  testWidgets('a wide panel still puts the name below the life total', (
    tester,
  ) async {
    // The stacked layout must not leak into the ordinary board.
    await pumpGame(tester, 4);
    await tester.pumpAndSettle();

    // p2 sits in the near row, which is not rotated.
    final name = tester.getRect(find.text('PLAYER LONGNAME 2'));
    final life = tester.getRect(find.text('40').at(2));
    expect(name.center.dy, greaterThan(life.center.dy));
  });

}

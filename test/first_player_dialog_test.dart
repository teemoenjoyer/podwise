import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podwise/core/feedback.dart';
import 'package:podwise/core/theme.dart';
import 'package:podwise/domain/models.dart';
import 'package:podwise/features/game/first_player_dialog.dart';

/// The draw is the one thing on the board that the table watches rather than
/// uses, so it is mostly animation — but the animation must not be able to
/// disagree with the answer, leave the dialog stuck, or grow it past the
/// height a landscape board has to give it.
void main() {
  const seats = [
    Seat(profileId: 'ben', name: 'Ben', colorIndex: 0, life: 40),
    Seat(profileId: 'dave', name: 'Dave', colorIndex: 1, life: 40),
    Seat(profileId: 'red', name: 'Morgan Bailey', colorIndex: 2, life: 40),
    Seat(profileId: 'jordan', name: 'Jordan', colorIndex: 3, life: 40),
  ];

  /// Puts the dialog on a landscape board, at the size a real phone gives it.
  Future<String?> show(WidgetTester tester, {int seed = 1}) async {
    tester.view.physicalSize = const Size(2424, 1080);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    String? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPodWiseTheme(),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showDialog<String>(
                context: context,
                barrierDismissible: false,
                builder: (_) => FirstPlayerDialog(
                  seats: seats,
                  feedback: const FeedbackService(
                    haptics: false,
                    sounds: false,
                  ),
                  random: Random(seed),
                ),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  /// Runs the whole spin and the burst that follows it.
  Future<void> roll(WidgetTester tester) async {
    await tester.tap(find.text('ROLL'));
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('the spin settles and stops asking', (tester) async {
    await show(tester);
    await roll(tester);

    // pumpAndSettle returning at all means every controller stopped — a
    // celebration that repeats forever would hang the test here rather than
    // fail it, which is the point of settling instead of pumping fixed frames.
    expect(find.textContaining('goes first'), findsOneWidget);
    expect(find.text('Rolling…'), findsNothing);
  });

  testWidgets('the name announced is the one that is returned', (tester) async {
    late String? returned;
    await show(tester);
    await roll(tester);

    final headline = tester
        .widgetList<Text>(find.textContaining('goes first'))
        .first
        .data!;
    final announced = headline.replaceAll(' goes first', '');

    await tester.tap(find.text('START'));
    await tester.pumpAndSettle();
    returned = seats.firstWhere((s) => s.name == announced).profileId;

    // The sparks and the pop are cosmetic, but they are keyed off the same
    // index the answer is, and the app must not congratulate one player and
    // hand the turn to another.
    expect(
      seats.firstWhere((s) => s.profileId == returned).name,
      announced,
    );
  });

  testWidgets('the celebration does not grow the dialog', (tester) async {
    await show(tester);
    final before = tester.getSize(find.byType(AlertDialog));

    await tester.tap(find.text('ROLL'));
    await tester.pump();
    // Part-way into the burst, with sparks at their furthest out.
    await tester.pump(const Duration(milliseconds: 2700));
    await tester.pump(const Duration(milliseconds: 400));

    // Sparks are painted beside the content, not laid out in it. If they were
    // in the layout they would push the buttons off a landscape screen, which
    // is the failure this dialog was already shaped around once.
    expect(tester.getSize(find.byType(AlertDialog)).height, before.height);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rolling again starts a fresh spin', (tester) async {
    await show(tester);
    await roll(tester);

    await tester.tap(find.text('AGAIN'));
    await tester.pump();
    // Past the headline cross-fade, which deliberately keeps the old line
    // around for a moment while the new one arrives.
    await tester.pump(const Duration(milliseconds: 260));

    // Straight back to a spin: leaving the previous winner lit, or the old
    // sparks on screen, would make it look like nothing happened.
    expect(find.text('Rolling…'), findsOneWidget);
    expect(find.textContaining('goes first'), findsNothing);

    await tester.pumpAndSettle();
    expect(find.textContaining('goes first'), findsOneWidget);
  });

  testWidgets('leaving mid-spin does not fault', (tester) async {
    await show(tester);
    await tester.tap(find.text('ROLL'));
    await tester.pump(const Duration(milliseconds: 600));

    // The burst measures the winning pill in a post-frame callback, so a
    // dialog that goes away at the wrong moment is a real disposal hazard.
    await tester.tap(find.text('SKIP'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podwise/core/theme.dart';
import 'package:podwise/data/database.dart';
import 'package:podwise/features/home/home_screen.dart';
import 'package:podwise/state/providers.dart';

/// The wordmark settles into place when the app opens.
///
/// The interesting requirements are not the movement itself: it must play
/// once per launch rather than every time Home is rebuilt, it must not push
/// the buttons underneath around while it runs, and somebody who has asked
/// for less motion should not get a smaller version of it.
void main() {
  late PodWiseDatabase db;
  late ProviderContainer container;

  setUp(() {
    resetWordmarkAnimation();
    db = PodWiseDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> openHome(
    WidgetTester tester, {
    bool disableAnimations = false,
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildPodWiseTheme(),
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: disableAnimations),
            child: const HomeScreen(),
          ),
        ),
      ),
    );
  }

  /// The tracking on the wordmark right now, which is what settles.
  double spacing(WidgetTester tester) =>
      tester.widget<Text>(find.text('PODWISE')).style!.letterSpacing!;

  testWidgets('it settles from tight tracking out to its real spacing', (
    tester,
  ) async {
    await openHome(tester);
    await tester.pump();
    final start = spacing(tester);

    // Nothing has moved yet: it waits for the first frame to be rasterized
    // and then a beat more, because the window is still behind the system
    // splash until then.
    expect(start, lessThan(10));

    await tester.pump(wordmarkStartBackstop + wordmarkSettleIn);
    await tester.pumpAndSettle();

    // pumpAndSettle returning at all means the animation ends — a logo that
    // never stopped would hang here rather than fail.
    expect(start, lessThan(spacing(tester)));
    expect(spacing(tester), 10);
  });

  testWidgets('it plays once per launch, not on every return to Home', (
    tester,
  ) async {
    await openHome(tester);
    await tester.pump(wordmarkStartBackstop + wordmarkSettleIn);
    await tester.pumpAndSettle();

    // Coming back from a game, history or settings rebuilds this screen.
    await tester.pumpWidget(const SizedBox.shrink());
    await openHome(tester);
    await tester.pump();

    // Already at its final tracking on the very first frame: no second run.
    expect(spacing(tester), 10);
  });

  testWidgets('reduce motion gets the wordmark already settled', (
    tester,
  ) async {
    await openHome(tester, disableAnimations: true);
    await tester.pump();
    expect(spacing(tester), 10);

    // Settled from the very first frame, and still settled once the start
    // that never needed to happen would have fired.
    await tester.pump(wordmarkStartBackstop + wordmarkSettleIn);
    await tester.pumpAndSettle();
    expect(spacing(tester), 10);
  });

  testWidgets('the logo always ends up visible, even if the start signal never comes', (
    tester,
  ) async {
    // The test binding never rasterizes a frame, which is exactly the shape
    // of the failure worth guarding: the wordmark opens at zero opacity, so
    // a start signal that never arrives would hide the logo for good.
    await openHome(tester);
    await tester.pump(wordmarkStartBackstop + wordmarkSettleIn);
    await tester.pumpAndSettle();

    expect(spacing(tester), 10);
    expect(
      tester.widget<Opacity>(find.ancestor(
        of: find.text('PODWISE'),
        matching: find.byType(Opacity),
      )).opacity,
      1,
    );
  });

  testWidgets('the buttons underneath do not move while it runs', (
    tester,
  ) async {
    await openHome(tester);
    await tester.pump();
    final early = tester.getRect(find.text('NEW GAME'));

    await tester.pump(wordmarkStartBackstop + wordmarkSettleIn);
    final middle = tester.getRect(find.text('NEW GAME'));

    await tester.pumpAndSettle();

    // Tracking changes how wide the wordmark is, not how tall — but if it
    // ever wrapped to two lines mid-animation the whole menu would jump under
    // someone's thumb.
    expect(middle, early);
    expect(tester.getRect(find.text('NEW GAME')), early);
  });
}

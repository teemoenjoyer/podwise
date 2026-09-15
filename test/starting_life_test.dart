import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podwise/core/theme.dart';
import 'package:podwise/features/setup/starting_life_field.dart';

/// Starting life is 40 for all but a handful of games, so the screen should
/// read as "it is 40" rather than "please choose".
void main() {
  /// A real phone in portrait, so the picker sheet has the room it actually
  /// has on a device rather than the test default of 800x600.
  void usePhone(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(1080, 2424)
      ..devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
  }

  Future<void> pump(
    WidgetTester tester,
    int value, {
    ValueChanged<int>? onChanged,
  }) {
    usePhone(tester);
    return tester.pumpWidget(
      MaterialApp(
        theme: buildPodWiseTheme(),
        home: Scaffold(
          body: StartingLifeField(value: value, onChanged: onChanged ?? (_) {}),
        ),
      ),
    );
  }

  testWidgets('40 is stated as the standard, not offered as an option', (
    tester,
  ) async {
    await pump(tester, 40);

    expect(find.text('40'), findsOneWidget);
    expect(find.text('Commander standard'), findsOneWidget);
    // The other totals are behind a tap; showing all six up front made
    // choosing look mandatory.
    expect(find.text('20'), findsNothing);
    expect(find.text('60'), findsNothing);
  });

  testWidgets('anything other than 40 says so', (tester) async {
    await pump(tester, 20);

    expect(find.text('20'), findsOneWidget);
    // Starting a Commander game on 20 by accident is a miserable way to find
    // out, so the deviation is called out rather than shown neutrally.
    expect(find.text('Changed from 40'), findsOneWidget);
  });

  testWidgets('tapping it opens the presets, with 40 marked', (tester) async {
    await pump(tester, 40);
    await tester.tap(find.byType(StartingLifeField));
    await tester.pumpAndSettle();

    for (final preset in startingLifePresets) {
      expect(find.text('$preset'), findsWidgets, reason: '$preset missing');
    }
    expect(find.text('Commander'), findsOneWidget);
    expect(find.text('Something else'), findsOneWidget);
  });

  testWidgets('choosing a preset reports it back', (tester) async {
    int? chosen;
    await pump(tester, 40, onChanged: (v) => chosen = v);

    await tester.tap(find.byType(StartingLifeField));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, '25'));
    await tester.pumpAndSettle();

    expect(chosen, 25);
  });

  testWidgets('a custom total can still be typed', (tester) async {
    int? chosen;
    await pump(tester, 40, onChanged: (v) => chosen = v);

    await tester.tap(find.byType(StartingLifeField));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Something else'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '77');
    await tester.tap(find.text('SET'));
    await tester.pumpAndSettle();

    // The brief is explicit that nobody is locked to 40.
    expect(chosen, 77);
  });
}

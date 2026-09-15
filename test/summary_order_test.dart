import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podwise/core/theme.dart';
import 'package:podwise/data/database.dart';
import 'package:podwise/domain/models.dart';
import 'package:podwise/features/game/game_summary_screen.dart';
import 'package:podwise/state/providers.dart';

/// The GAME OVER screen has to agree with what was written to history.
///
/// It used to sort by life with its own copy of the comparator, so a game
/// where somebody was knocked out on full life displayed one order and saved a
/// different one. Testing the domain function on its own never caught that,
/// because the screen never called it.
void main() {
  late PodWiseDatabase db;
  late ProviderContainer container;

  const names = ['Ben', 'Dave', 'Morgan Bailey', 'Jordan'];

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

  /// The case that exposed the bug: the first player out keeps the most life,
  /// and the last one out has the least.
  Future<void> play() async {
    final notifier = container.read(activeGameProvider.notifier);
    notifier.start(
      startingLife: 40,
      players: const [
        PlayerProfile(id: 'ben', name: 'Ben', colorIndex: 0),
        PlayerProfile(id: 'dave', name: 'Dave', colorIndex: 1),
        PlayerProfile(id: 'red', name: 'Morgan Bailey', colorIndex: 2),
        PlayerProfile(id: 'jordan', name: 'Jordan', colorIndex: 3),
      ],
    );

    notifier.setLife('dave', -16);
    notifier.setLife('red', -49);

    notifier.toggleEliminated('ben'); // out first, still on 40
    notifier.toggleEliminated('dave');
    notifier.toggleEliminated('red'); // out last, on -49

    // Only Jordan is left, so the game settles itself — which writes to the
    // database, and that is genuinely asynchronous.
    await Future<void>.delayed(const Duration(milliseconds: 40));
  }

  /// Names in the order the standings render them.
  List<String> standingsOn(WidgetTester tester) => tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data)
      .whereType<String>()
      .where(names.contains)
      .toList();

  Future<List<String>> showSummary(WidgetTester tester) async {
    // Both the game and the summary need real async work, so they run outside
    // the fake clock that a widget test installs.
    await tester.runAsync(play);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildPodWiseTheme(),
          home: const GameSummaryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final shown = standingsOn(tester);
    // The winner is also named in the header, above the standings.
    return shown.sublist(shown.length - names.length);
  }

  testWidgets('the standings follow the knockouts, not the life totals', (
    tester,
  ) async {
    expect(await showSummary(tester), [
      'Jordan', // survived
      'Morgan Bailey', // out third
      'Dave', // out second
      'Ben', // out first, on a full 40
    ]);
  });

  testWidgets('what is shown matches what was saved', (tester) async {
    final shown = await showSummary(tester);

    final saved = await tester.runAsync(() async {
      final games = await db.recentGames();
      final rows = (await db.participantsOf(games.single.id)).toList()
        ..sort((a, b) => (a.position ?? 99).compareTo(b.position ?? 99));
      return rows.map((p) => p.name).toList();
    });

    // Two orderings for one game is exactly how this went wrong.
    expect(shown, saved);
  });

  test('history reads in finishing order too', () async {
    await play();
    final history = await container.read(gameHistoryProvider.future);

    expect(history.single.results.map((r) => r.name), [
      'Jordan',
      'Morgan Bailey',
      'Dave',
      'Ben',
    ]);
    expect(history.single.results.first.won, isTrue);
  });
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podwise/core/theme.dart';
import 'package:podwise/data/database.dart';
import 'package:podwise/features/commander/commander_art.dart';
import 'package:podwise/state/providers.dart';

/// Deck rows show their commander's art instead of a grey card glyph.
///
/// The failure worth guarding is the empty case, and it is not rare: a deck
/// the v9 relink could not match has no card ids at all, and a phone with no
/// signal on its first run has no art for the ones it does have. Neither may
/// leave a hole in the row.
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

  Future<void> cache(String id, String name, {String? art}) => db.cacheCards([
    CachedCardsCompanion.insert(
      id: id,
      name: name,
      searchName: name.toLowerCase(),
      typeLine: 'Legendary Creature',
      cachedAt: DateTime(2026),
      imageArtCrop: Value(art),
    ),
  ]);

  Future<void> show(WidgetTester tester, List<String> ids) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildPodWiseTheme(),
          home: Scaffold(body: CommanderArt(commanderIds: ids)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('a deck shows its commander art', (tester) async {
    await tester.runAsync(
      () => cache('shao', 'Shao Jun', art: 'https://cards/shao.jpg'),
    );
    await show(tester, ['shao']);

    final art = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(art.imageUrl, 'https://cards/shao.jpg');
  });

  testWidgets('a partner pair shows the first commander', (tester) async {
    await tester.runAsync(() async {
      await cache('joel', 'Joel', art: 'https://cards/joel.jpg');
      await cache('ellie', 'Ellie', art: 'https://cards/ellie.jpg');
    });
    await show(tester, ['joel', 'ellie']);

    // One thumbnail, and it is the primary commander — the same card the
    // GAME OVER hero uses, so a deck looks like itself everywhere.
    expect(find.byType(CachedNetworkImage), findsOneWidget);
    expect(
      tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage)).imageUrl,
      'https://cards/joel.jpg',
    );
  });

  testWidgets('a deck with no card ids falls back to the glyph', (
    tester,
  ) async {
    // Any deck the relink could not match still looks like a deck row.
    await show(tester, const []);

    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byIcon(Icons.style_rounded), findsOneWidget);
  });

  testWidgets('an id the cache has never seen falls back too', (tester) async {
    await show(tester, ['never-cached']);

    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byIcon(Icons.style_rounded), findsOneWidget);
  });

  testWidgets('a cached card with no art falls back', (tester) async {
    await tester.runAsync(() => cache('plain', 'Plain Card'));
    await show(tester, ['plain']);

    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.byIcon(Icons.style_rounded), findsOneWidget);
  });

  testWidgets('the glyph holds the tile until the art arrives', (tester) async {
    await tester.runAsync(
      () => cache('shao', 'Shao Jun', art: 'https://cards/shao.jpg'),
    );
    await show(tester, ['shao']);

    // Nothing can actually fetch in a widget test, which is the same state as
    // a first run with no signal — and an empty box there is worse than the
    // plain glyph these rows used to show.
    expect(find.byIcon(Icons.style_rounded), findsOneWidget);
  });

  testWidgets('the thumbnail is the same size with or without art', (
    tester,
  ) async {
    await tester.runAsync(
      () => cache('shao', 'Shao Jun', art: 'https://cards/shao.jpg'),
    );
    await show(tester, ['shao']);
    final withArt = tester.getSize(find.byType(CommanderArt));

    await show(tester, const []);
    final without = tester.getSize(find.byType(CommanderArt));

    // Rows must not jump about as art loads, or a list of decks reflows while
    // somebody is trying to tap one.
    expect(withArt, without);
  });
}

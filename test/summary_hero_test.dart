import 'package:cached_network_image/cached_network_image.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podwise/core/theme.dart';
import 'package:podwise/data/database.dart';
import 'package:podwise/domain/commander.dart';
import 'package:podwise/domain/models.dart';
import 'package:podwise/features/game/game_summary_screen.dart';
import 'package:podwise/state/providers.dart';

/// The GAME OVER screen shows the winning commander's art behind the trophy.
///
/// Most of the risk is in what happens when there is no art, which is a
/// commoner case than it sounds: a table that never entered commanders, a
/// phone with no signal, and every pod borrowed from another phone — that
/// payload deliberately carries card names and no image URLs. None of those
/// may leave a gap, a broken-image glyph, or a shifted layout.
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

  const atraxa = MagicCard(
    id: 'atraxa',
    name: 'Atraxa, Praetors\' Voice',
    typeLine: 'Legendary Creature',
    colorIdentity: {},
    imageArtCrop: 'https://cards.scryfall.io/art_crop/atraxa.jpg',
    artist: 'Victor Adame Minguez',
  );

  /// Plays a two-player game that Ben wins, optionally with a commander.
  Future<void> play({CommanderSet? benCommander, String? benLabel}) async {
    final notifier = container.read(activeGameProvider.notifier);
    notifier.start(
      startingLife: 40,
      players: const [
        PlayerProfile(id: 'ben', name: 'Ben', colorIndex: 0),
        PlayerProfile(id: 'dave', name: 'Dave', colorIndex: 1),
      ],
      commanders: {'ben': ?benCommander},
      commanderLabels: {'ben': ?benLabel},
    );
    notifier.toggleEliminated('dave');
    // The last player standing ends the game itself, and that writes to the
    // database, which is genuinely asynchronous.
    await Future<void>.delayed(const Duration(milliseconds: 40));
  }

  Future<void> showSummary(
    WidgetTester tester, {
    CommanderSet? benCommander,
    String? benLabel,
    Size size = const Size(1080, 2424),
    List<Override> overrides = const [],
  }) async {
    if (overrides.isNotEmpty) {
      container.dispose();
      container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db), ...overrides],
      );
    }
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);

    await tester.runAsync(
      () => play(benCommander: benCommander, benLabel: benLabel),
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildPodWiseTheme(),
          home: const GameSummaryScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the winning commander backs the header', (tester) async {
    await showSummary(
      tester,
      benCommander: const CommanderSet(cards: [atraxa]),
    );

    final art = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(art.imageUrl, atraxa.imageArtCrop);

    // Named as well as pictured. The name is what a player reads; the art is
    // what they recognise.
    expect(find.textContaining('ATRAXA', findRichText: true), findsOneWidget);
    expect(find.text('ART BY VICTOR ADAME MINGUEZ'), findsOneWidget);
  });

  testWidgets('a commander with no art shows no backdrop', (tester) async {
    await showSummary(
      tester,
      benCommander: const CommanderSet(
        cards: [
          MagicCard(
            id: 'krenko',
            name: 'Krenko, Mob Boss',
            typeLine: 'Legendary Creature',
            colorIdentity: {},
          ),
        ],
      ),
    );

    // This is the borrowed-pod case: the commander is known, the picture is
    // not. The name must still be there.
    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.text('KRENKO, MOB BOSS'), findsOneWidget);
    expect(find.textContaining('ART BY'), findsNothing);
  });

  testWidgets('a deck that only knows its commander by name still names it', (
    tester,
  ) async {
    // The case that started this: a deck carried over from before card ids
    // existed knows "Shao Jun" and holds no card, so the hero showed nothing
    // at all where the commander should have been.
    await showSummary(tester, benLabel: 'Shao Jun');

    expect(find.text('SHAO JUN'), findsOneWidget);
    expect(find.byType(CachedNetworkImage), findsNothing);
  });

  testWidgets('a game with no commanders looks as it always did', (
    tester,
  ) async {
    await showSummary(tester);

    expect(find.byType(CachedNetworkImage), findsNothing);
    expect(find.text('GAME OVER'), findsOneWidget);
    expect(find.text('Ben'), findsWidgets);
    expect(find.text('wins with 40 life'), findsOneWidget);
  });

  testWidgets('known art with an unknown artist is still shown', (
    tester,
  ) async {
    // Every card cached before the artist column existed looks like this, so
    // this is the state most of a real install is in right after upgrading.
    await showSummary(
      tester,
      benCommander: const CommanderSet(
        cards: [
          MagicCard(
            id: 'atraxa',
            name: 'Atraxa',
            typeLine: 'Legendary Creature',
            colorIdentity: {},
            imageArtCrop: 'https://cards.scryfall.io/art_crop/atraxa.jpg',
          ),
        ],
      ),
    );

    expect(find.byType(CachedNetworkImage), findsOneWidget);
    expect(find.textContaining('ART BY'), findsNothing);
  });

  testWidgets('a credit looked up in the background appears when it lands', (
    tester,
  ) async {
    const uncredited = MagicCard(
      id: 'atraxa',
      name: 'Atraxa',
      typeLine: 'Legendary Creature',
      colorIdentity: {},
      imageArtCrop: 'https://cards.scryfall.io/art_crop/atraxa.jpg',
    );

    await showSummary(
      tester,
      benCommander: const CommanderSet(cards: [uncredited]),
      overrides: [
        cardArtistProvider(
          uncredited,
        ).overrideWith((ref) async => 'Seb McKinnon'),
      ],
    );

    await tester.pumpAndSettle();

    // The art comes from the cache and the credit from the lookup, so the
    // picture is never held back waiting for the name.
    expect(find.byType(CachedNetworkImage), findsOneWidget);
    expect(find.text('ART BY SEB MCKINNON'), findsOneWidget);
  });

  testWidgets('the hero does not overflow in landscape', (tester) async {
    // This screen is briefly landscape on the way back from the board, and is
    // permanently landscape for anyone with rotation locked. It has already
    // overflowed here once, by 97 pixels on a real phone.
    await showSummary(
      tester,
      benCommander: const CommanderSet(cards: [atraxa]),
      size: const Size(2424, 1080),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
  });

  testWidgets('the art never covers the standings', (tester) async {
    await showSummary(
      tester,
      benCommander: const CommanderSet(cards: [atraxa]),
    );

    // The backdrop is sized by the header it sits behind. If it were ever
    // given a height of its own it could run down over the finishing order,
    // which is the part of this screen people actually read.
    final backdrop = tester.getRect(find.byType(CachedNetworkImage));
    final standings = tester.getRect(find.text('Dave'));
    expect(backdrop.overlaps(standings), isFalse);
  });
}

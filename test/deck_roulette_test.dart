import 'dart:math';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:podwise/data/database.dart';
import 'package:podwise/domain/deck_roulette.dart';
import 'package:podwise/domain/pod.dart';

/// Deck Roulette hands everyone somebody else's deck. Two rules make or break
/// it: nobody gets their own list back, and no deck is dealt twice — a deck is
/// a physical object and cannot be at two seats at once.
void main() {
  DeckProfile deck(String id, String owner) =>
      DeckProfile(playerId: owner, playerName: owner, deckId: id);

  List<DeckProfile> pool() => [
    deck('a1', 'ana'),
    deck('a2', 'ana'),
    deck('b1', 'ben'),
    deck('c1', 'cal'),
    deck('d1', 'dee'),
  ];

  const players = ['ana', 'ben', 'cal', 'dee'];

  group('dealing', () {
    test('nobody is handed their own deck', () {
      for (var seed = 0; seed < 200; seed++) {
        final dealt = DeckRoulette.deal(
          playerIds: players,
          pool: pool(),
          random: Random(seed),
        );
        for (final entry in dealt.entries) {
          expect(
            entry.value.playerId,
            isNot(entry.key),
            reason: 'seed $seed gave ${entry.key} their own deck',
          );
        }
      }
    });

    test('no deck is dealt to two people', () {
      for (var seed = 0; seed < 200; seed++) {
        final dealt = DeckRoulette.deal(
          playerIds: players,
          pool: pool(),
          random: Random(seed),
        );
        final ids = dealt.values.map((d) => d.deckId).toList();
        expect(ids.toSet(), hasLength(ids.length), reason: 'seed $seed');
      }
    });

    test('everybody gets something when there is enough to go round', () {
      for (var seed = 0; seed < 100; seed++) {
        final dealt = DeckRoulette.deal(
          playerIds: players,
          pool: pool(),
          random: Random(seed),
        );
        expect(dealt, hasLength(players.length), reason: 'seed $seed');
      }
    });

    test('it does not deal the same hand every time', () {
      final hands = {
        for (var seed = 0; seed < 30; seed++)
          DeckRoulette.deal(
            playerIds: players,
            pool: pool(),
            random: Random(seed),
          ).entries.map((e) => '${e.key}:${e.value.deckId}').join(),
      };
      expect(hands.length, greaterThan(1));
    });

    test(
      'a player nobody can supply is left out rather than given their own',
      () {
        // Only Ana owns anything, so Ana cannot be dealt a deck at all.
        final dealt = DeckRoulette.deal(
          playerIds: const ['ana', 'ben'],
          pool: [deck('a1', 'ana')],
          random: Random(1),
        );

        expect(dealt['ben']?.deckId, 'a1');
        expect(dealt.containsKey('ana'), isFalse);
      },
    );

    test('unsaved placeholder decks are never dealt', () {
      final dealt = DeckRoulette.deal(
        playerIds: const ['ana', 'ben'],
        // deckId '' is the placeholder for a player who has saved nothing.
        pool: [const DeckProfile(playerId: 'ana', playerName: 'Ana')],
        random: Random(1),
      );
      expect(dealt, isEmpty);
    });
  });

  group('re-rolling one player', () {
    test('gives them a different deck and leaves everyone else alone', () {
      final dealt = DeckRoulette.deal(
        playerIds: players,
        pool: pool(),
        random: Random(4),
      );
      final after = DeckRoulette.reroll(
        playerId: 'ben',
        current: dealt,
        pool: pool(),
        random: Random(9),
      );

      expect(after['ben']!.deckId, isNot(dealt['ben']!.deckId));
      for (final other in ['ana', 'cal', 'dee']) {
        expect(after[other]!.deckId, dealt[other]!.deckId);
      }
    });

    test('never lands on their own deck, or one already in play', () {
      var dealt = DeckRoulette.deal(
        playerIds: players,
        pool: pool(),
        random: Random(2),
      );
      for (var seed = 0; seed < 60; seed++) {
        dealt = DeckRoulette.reroll(
          playerId: 'ana',
          current: dealt,
          pool: pool(),
          random: Random(seed),
        );
        expect(dealt['ana']!.playerId, isNot('ana'));
        final ids = dealt.values.map((d) => d.deckId).toList();
        expect(ids.toSet(), hasLength(ids.length));
      }
    });

    test('leaves the deal untouched when there is nothing else to give', () {
      final current = {'ben': deck('a1', 'ana')};
      final after = DeckRoulette.reroll(
        playerId: 'ben',
        current: current,
        pool: [deck('a1', 'ana')],
        random: Random(1),
      );
      expect(after['ben']!.deckId, 'a1');
    });
  });

  group('the results do not touch deck power', () {
    late PodWiseDatabase db;

    setUp(() => db = PodWiseDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<void> saveGame(String id, {required bool roulette}) async {
      await db.saveFinishedGame(
        game: GameRow(
          id: id,
          startedAt: DateTime(2026),
          finishedAt: DateTime(2026, 1, 1, 1),
          startingLife: 40,
          deckRoulette: roulette,
          winnerProfileId: 'ana',
        ),
        participants: [
          GameParticipantsCompanion.insert(
            gameId: id,
            profileId: 'ana',
            name: 'Ana',
            seatIndex: 0,
            colorIndex: 0,
            finalLife: 40,
            deckId: const Value('b1'),
            position: const Value(1),
          ),
        ],
      );
    }

    test('a roulette game is in history but not in the deck record', () async {
      await saveGame('r1', roulette: true);

      // The night happened and counts for the player...
      expect(await db.recentGames(), hasLength(1));
      expect((await db.playerStatistics())['ana']!.wins, 1);
      // ...but Ben's deck did not win anything; somebody else was piloting it.
      expect(await db.deckRecords(), isEmpty);
    });

    test('an ordinary game still counts for the deck', () async {
      await saveGame('n1', roulette: false);
      expect((await db.deckRecords())['b1'], (games: 1, wins: 1));
    });

    test('one roulette night cannot dilute a real record', () async {
      await saveGame('n1', roulette: false);
      await saveGame('r1', roulette: true);
      await saveGame('n2', roulette: false);

      expect((await db.deckRecords())['b1'], (games: 2, wins: 2));
    });
  });
}

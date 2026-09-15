import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:podwise/domain/commander.dart';
import 'package:podwise/domain/pod.dart';
import 'package:podwise/domain/pod_builder.dart';

DeckProfile deck(
  String id, {
  int power = 5,
  Set<ManaColor> colors = const {},
  Set<DeckArchetype> archetypes = const {},
  Set<InteractionType> interaction = const {},
  int games = 0,
  int wins = 0,
}) => DeckProfile(
  playerId: id,
  playerName: id,
  colorIdentity: colors,
  power: power,
  archetypes: archetypes,
  interaction: interaction,
  gamesPlayed: games,
  wins: wins,
);

List<DeckProfile> decks(int n, {int power = 5}) => [
  for (var i = 0; i < n; i++) deck('p$i', power: power),
];

/// Fixed seed so ranking is reproducible; the builder shuffles to break ties.
Random seeded() => Random(1234);

void main() {
  group('pod sizes', () {
    test('three to six players stay at one table', () {
      for (var n = 3; n <= 6; n++) {
        expect(PodBuilder.podSizes(n), [n], reason: '$n players');
      }
    });

    test('matches the agreed defaults from seven upward', () {
      expect(PodBuilder.podSizes(7), [4, 3]);
      expect(PodBuilder.podSizes(8), [4, 4]);
      expect(PodBuilder.podSizes(9), [5, 4]);
      expect(PodBuilder.podSizes(10), [5, 5]);
    });

    test('a pod of three only ever appears beside a pod of four', () {
      for (var n = 3; n <= 24; n++) {
        final sizes = PodBuilder.podSizes(n);
        if (sizes.length > 1 && sizes.contains(3)) {
          expect(
            sizes.contains(4),
            isTrue,
            reason: '$n players produced $sizes with no pod of four',
          );
        }
      }
    });

    test('no pod ever exceeds five once the group splits', () {
      for (var n = 7; n <= 24; n++) {
        for (final size in PodBuilder.podSizes(n)) {
          expect(size, lessThanOrEqualTo(5), reason: '$n players');
        }
      }
    });

    test('larger counts keep splitting cleanly', () {
      expect(PodBuilder.podSizes(11), [4, 4, 3]);
      expect(PodBuilder.podSizes(12), [4, 4, 4]);
      expect(PodBuilder.podSizes(13), [5, 4, 4]);
      expect(PodBuilder.podSizes(14), [5, 5, 4]);
      expect(PodBuilder.podSizes(15), [5, 5, 5]);
    });

    test('sizes always account for every player', () {
      for (var n = 2; n <= 24; n++) {
        expect(PodBuilder.podSizes(n).fold(0, (a, b) => a + b), n);
      }
    });

    test('honours a manual pod count override', () {
      expect(PodBuilder.podSizes(8, podCount: 2), [4, 4]);
      expect(PodBuilder.podSizes(12, podCount: 3), [4, 4, 4]);
      // The user may override six players into two pods if they want to.
      expect(PodBuilder.podSizes(6, podCount: 2), [3, 3]);
    });

    test('offers alternative pod counts where they exist', () {
      // Eight only works as 4+4; three pods would need at least nine players.
      expect(PodBuilder.validPodCounts(8), [2]);
      // Ten works as 5+5 or as 4+3+3 — the latter is legal because it still
      // contains a pod of four.
      expect(PodBuilder.validPodCounts(10), [2, 3]);
      expect(PodBuilder.validPodCounts(12), contains(3));
      expect(PodBuilder.validPodCounts(5), contains(1));
    });

    test('never offers a split that would be all threes', () {
      // Nine into three pods would be 3+3+3, with no pod of four.
      expect(PodBuilder.validPodCounts(9), isNot(contains(3)));
      expect(PodBuilder.validPodCounts(6), isNot(contains(2)));
    });
  });

  group('split enumeration', () {
    test('finds every distinct 4+4 split of eight players', () {
      // C(7,3) = 35: player 0 is pinned to the first pod, so relabelling the
      // two pods does not produce duplicates.
      expect(PodBuilder.enumerateSplits(8, [4, 4]), hasLength(35));
    });

    test('finds every distinct 5+5 split of ten players', () {
      expect(PodBuilder.enumerateSplits(10, [5, 5]), hasLength(126));
    });

    test('every split uses each player exactly once', () {
      for (final split in PodBuilder.enumerateSplits(8, [4, 4])) {
        final all = [for (final pod in split) ...pod];
        expect(all, hasLength(8));
        expect(all.toSet(), hasLength(8));
      }
    });

    test('produces no duplicate assignments', () {
      final splits = PodBuilder.enumerateSplits(8, [4, 4]);
      final signatures = splits
          .map((s) => s.map((pod) => (pod..sort()).join(',')).toList()..sort())
          .map((s) => s.join('/'))
          .toSet();
      expect(signatures, hasLength(splits.length));
    });
  });

  group('power balance', () {
    test('separates the strongest decks rather than stacking them', () {
      final players = [
        deck('strong1', power: 9),
        deck('strong2', power: 9),
        deck('strong3', power: 9),
        deck('strong4', power: 9),
        deck('weak1', power: 2),
        deck('weak2', power: 2),
        deck('weak3', power: 2),
        deck('weak4', power: 2),
      ];

      final best = PodBuilder.build(
        players: players,
        mode: PodMode.fairest,
        random: seeded(),
      ).first;

      // Each pod should end up with two strong and two weak decks.
      for (final pod in best.pods) {
        final strong = pod.members.where((m) => m.power == 9).length;
        expect(strong, 2, reason: 'power should be spread, not stacked');
      }
      expect(best.score.powerBalance, greaterThan(0.9));
    });

    test('a perfectly even table scores full marks', () {
      final best = PodBuilder.build(
        players: decks(8),
        mode: PodMode.fairest,
        random: seeded(),
      ).first;
      expect(best.score.powerBalance, 1.0);
    });
  });

  group('archetype diversity', () {
    test('avoids putting four graveyard decks in one pod', () {
      // The brief calls out this exact case.
      final players = [
        for (var i = 0; i < 4; i++)
          deck('gy$i', archetypes: {DeckArchetype.graveyard}),
        for (var i = 0; i < 4; i++)
          deck('other$i', archetypes: {DeckArchetype.tokens}),
      ];

      final best = PodBuilder.build(
        players: players,
        mode: PodMode.diverse,
        random: seeded(),
      ).first;

      for (final pod in best.pods) {
        final graveyard = pod.members
            .where((m) => m.archetypes.contains(DeckArchetype.graveyard))
            .length;
        expect(
          graveyard,
          lessThan(4),
          reason: 'four graveyard decks should not share a pod',
        );
      }
    });

    test('a couple of shared archetypes in a big pod is mild, not total', () {
      // Two graveyard decks among eight players is a minor overlap. Measuring
      // concentration against only the *tagged* decks would call it total.
      final players = [
        deck('gy1', archetypes: {DeckArchetype.graveyard}),
        deck('gy2', archetypes: {DeckArchetype.graveyard}),
        for (var i = 0; i < 6; i++) deck('untagged$i'),
      ];
      final result = PodBuilder.build(
        players: players,
        mode: PodMode.diverse,
        random: seeded(),
      ).first;
      expect(result.score.archetypeDiversity, greaterThan(0.5));
    });

    test('untagged decks do not distort the score', () {
      // Nobody has tagged anything, so this dimension must stay neutral rather
      // than reporting a false problem.
      final result = PodBuilder.build(
        players: decks(8),
        mode: PodMode.diverse,
        random: seeded(),
      ).first;
      expect(result.score.archetypeDiversity, 1.0);
    });
  });

  group('colour diversity', () {
    test('splits up decks sharing a colour identity', () {
      final players = [
        for (var i = 0; i < 4; i++) deck('mono$i', colors: {ManaColor.blue}),
        for (var i = 0; i < 4; i++) deck('green$i', colors: {ManaColor.green}),
      ];

      final best = PodBuilder.build(
        players: players,
        mode: PodMode.diverse,
        random: seeded(),
      ).first;

      for (final pod in best.pods) {
        expect(
          pod.colors.length,
          greaterThan(1),
          reason: 'a pod of four mono-blue decks is the worst case',
        );
      }
    });
  });

  group('missing data stays neutral', () {
    // Every dimension must be silent when nobody has entered anything for it.
    // Reporting "very poor" for data the group never supplied is a statement
    // about the app, not about the pods.
    test('colour diversity is neutral when no colours are recorded', () {
      final result = PodBuilder.build(
        players: decks(6),
        mode: PodMode.smartPods,
        random: seeded(),
      ).first;
      expect(result.score.colorDiversity, 1.0);
    });

    test('a pair with no colours recorded does not count as identical', () {
      final players = [
        deck('blue1', colors: {ManaColor.blue}),
        deck('blue2', colors: {ManaColor.blue}),
        deck('unknown1'),
        deck('unknown2'),
        deck('green1', colors: {ManaColor.green}),
        deck('green2', colors: {ManaColor.green}),
      ];
      final result = PodBuilder.build(
        players: players,
        mode: PodMode.diverse,
        random: seeded(),
      ).first;
      // Some colours are known, so the dimension is live, but the unrated
      // players must not drag it to zero.
      expect(result.score.colorDiversity, greaterThan(0.0));
    });

    test('a pod with no interaction recorded counts as unknown, not empty', () {
      // One player fills in a single removal spell; the other pod has nothing
      // recorded at all. That pod is unknown, not defenceless.
      // Eight, so this actually splits into two pods — six players now play as
      // a single table and there would be no second pod to compare against.
      final players = [
        deck('recorded', interaction: {InteractionType.creatureRemoval}),
        for (var i = 0; i < 7; i++) deck('blank$i'),
      ];
      final result = PodBuilder.build(
        players: players,
        mode: PodMode.competitiveBalance,
        random: seeded(),
      ).first;

      // Previously this scored ~0.1 and reported "Very poor" to the table.
      expect(result.score.interactionCoverage, greaterThan(0.5));
    });

    test('an entirely unrated group scores every dimension neutral', () {
      final result = PodBuilder.build(
        players: decks(8),
        mode: PodMode.smartPods,
        random: seeded(),
      ).first;

      expect(result.score.powerBalance, 1.0);
      expect(result.score.colorDiversity, 1.0);
      expect(result.score.archetypeDiversity, 1.0);
      expect(result.score.freshMatchups, 1.0);
      expect(result.score.interactionCoverage, 1.0);
      expect(result.score.playerBalance, 1.0);
    });
  });

  group('fresh matchups', () {
    test('separates players who keep being drawn together', () {
      // Dave and Sarah have played together constantly; Dave and Chris never.
      final history = <String, int>{
        matchupKey('dave', 'sarah'): 8,
        matchupKey('dave', 'chris'): 0,
      };

      final players = [
        deck('dave'),
        deck('sarah'),
        deck('chris'),
        deck('alex'),
        deck('ben'),
        deck('jo'),
        deck('kim'),
        deck('lee'),
      ];

      final best = PodBuilder.build(
        players: players,
        mode: PodMode.freshMatchups,
        history: history,
        random: seeded(),
      ).first;

      final davePod = best.pods.firstWhere(
        (p) => p.members.any((m) => m.playerId == 'dave'),
      );
      expect(
        davePod.members.any((m) => m.playerId == 'sarah'),
        isFalse,
        reason: 'the most repeated pairing should be broken up',
      );
    });

    test('no history means the dimension stays neutral', () {
      final result = PodBuilder.build(
        players: decks(8),
        mode: PodMode.freshMatchups,
        random: seeded(),
      ).first;
      expect(result.score.freshMatchups, 1.0);
    });

    test('matchup keys ignore the order of the pair', () {
      expect(matchupKey('a', 'b'), matchupKey('b', 'a'));
    });
  });

  group('interaction coverage', () {
    test('prefers pods that can answer things', () {
      final players = [
        deck('removal1', interaction: {InteractionType.creatureRemoval}),
        deck('removal2', interaction: {InteractionType.creatureRemoval}),
        deck('wipe1', interaction: {InteractionType.boardWipe}),
        deck('wipe2', interaction: {InteractionType.boardWipe}),
        deck('counter1', interaction: {InteractionType.stackInteraction}),
        deck('counter2', interaction: {InteractionType.stackInteraction}),
        deck('gy1', interaction: {InteractionType.graveyardHate}),
        deck('gy2', interaction: {InteractionType.graveyardHate}),
      ];

      final best = PodBuilder.build(
        players: players,
        mode: PodMode.competitiveBalance,
        random: seeded(),
      ).first;

      // Each pod should end up with several different kinds of answer rather
      // than four copies of the same one.
      for (final pod in best.pods) {
        expect(pod.interaction.length, greaterThanOrEqualTo(2));
      }
    });

    test('unrecorded interaction stays neutral rather than scoring zero', () {
      final result = PodBuilder.build(
        players: decks(8),
        mode: PodMode.competitiveBalance,
        random: seeded(),
      ).first;
      expect(result.score.interactionCoverage, 1.0);
    });
  });

  group('effective power', () {
    test('is the raw rating until enough games are played', () {
      expect(deck('a', power: 6, games: 3, wins: 3).effectivePower, 6.0);
    });

    test('rises for a deck that overperforms its rating', () {
      final overperformer = deck('a', power: 5, games: 20, wins: 12);
      expect(overperformer.effectivePower, greaterThan(5));
    });

    test('falls for a deck that never wins', () {
      final underperformer = deck('a', power: 7, games: 20, wins: 0);
      expect(underperformer.effectivePower, lessThan(7));
    });

    test('correction is capped so results cannot overrule the group', () {
      final dominant = deck('a', power: 5, games: 50, wins: 50);
      expect(dominant.effectivePower, lessThanOrEqualTo(6.5));
    });

    test('stays inside the 1-10 scale', () {
      expect(deck('a', power: 10, games: 40, wins: 40).effectivePower, 10.0);
      expect(deck('b', power: 1, games: 40, wins: 0).effectivePower, 1.0);
    });
  });

  group('building', () {
    test('returns several ranked alternatives for rebuild', () {
      final results = PodBuilder.build(
        players: decks(8),
        mode: PodMode.smartPods,
        random: seeded(),
      );
      expect(results.length, greaterThan(1));
      // Sorted best first.
      for (var i = 1; i < results.length; i++) {
        expect(
          results[i - 1].score.total,
          greaterThanOrEqualTo(results[i].score.total),
        );
      }
    });

    test('every player appears exactly once in an assignment', () {
      for (var n = 5; n <= 10; n++) {
        final best = PodBuilder.build(
          players: decks(n),
          mode: PodMode.smartPods,
          random: seeded(),
        ).first;
        final assigned = [for (final pod in best.pods) ...pod.members];
        expect(assigned, hasLength(n));
        expect(assigned.map((d) => d.playerId).toSet(), hasLength(n));
      }
    });

    test('five players produce a single pod', () {
      final best = PodBuilder.build(
        players: decks(5),
        mode: PodMode.smartPods,
        random: seeded(),
      ).first;
      expect(best.pods, hasLength(1));
      expect(best.pods.first.size, 5);
    });

    test('fewer than two players yields nothing', () {
      expect(
        PodBuilder.build(players: decks(1), mode: PodMode.smartPods),
        isEmpty,
      );
    });

    test('random mode scores every split equally', () {
      final results = PodBuilder.build(
        players: decks(8),
        mode: PodMode.random,
        random: seeded(),
      );
      // Nothing is weighted, so the shuffle decides — which is the point.
      expect(results.every((r) => r.score.total == 0), isTrue);
    });

    test('smart pods balances power even when other data is missing', () {
      final players = [
        for (var i = 0; i < 4; i++) deck('strong$i', power: 9),
        for (var i = 0; i < 4; i++) deck('weak$i', power: 2),
      ];
      final best = PodBuilder.build(
        players: players,
        mode: PodMode.smartPods,
        random: seeded(),
      ).first;
      expect(best.score.powerBalance, greaterThan(0.8));
    });
  });

  group('score descriptions', () {
    test('map to plain language', () {
      expect(PodScore.describe(0.9), 'Excellent');
      expect(PodScore.describe(0.75), 'Good');
      expect(PodScore.describe(0.55), 'Fair');
      expect(PodScore.describe(0.35), 'Poor');
      expect(PodScore.describe(0.1), 'Very poor');
    });
  });
}

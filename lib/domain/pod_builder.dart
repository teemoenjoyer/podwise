import 'dart:math';

import 'pod.dart';

/// How many previous games each pair of players has shared.
///
/// Keyed by an unordered pair, so lookups don't care which player is named
/// first. Use [matchupKey] to build keys.
typedef MatchupHistory = Map<String, int>;

/// Unordered key for a pair of players.
String matchupKey(String a, String b) =>
    a.compareTo(b) <= 0 ? '$a|$b' : '$b|$a';

/// Relative importance of each scoring component, per mode.
///
/// These are judgement calls, not measurements. They are kept here, in one
/// table, precisely so they can be argued with and tuned.
const _weights = <PodMode, Map<String, double>>{
  PodMode.random: {},
  PodMode.fairest: {'power': 1.0},
  PodMode.diverse: {'color': 1.0, 'archetype': 1.2},
  PodMode.freshMatchups: {'fresh': 1.0, 'power': 0.2},
  PodMode.casualBalance: {'power': 1.0, 'archetype': 0.4, 'playerBalance': 0.4},
  // Deliberately has no 'power' weight. Evening power out across pods is the
  // opposite of what this mode is for, and including both would have them
  // pulling against each other.
  PodMode.competitiveBalance: {
    'tier': 1.0,
    'interaction': 0.4,
    'archetype': 0.3,
  },
  // No weights, so every split ties and the shuffle decides — the decks are
  // the point of this mode, not the seating.
  PodMode.deckRoulette: {},
  PodMode.smartPods: {
    'power': 1.0,
    'archetype': 0.7,
    'color': 0.4,
    'fresh': 0.8,
    'interaction': 0.5,
    'playerBalance': 0.3,
  },
};

/// Builds and ranks pod assignments.
///
/// The brief asks for this to be treated as an optimisation problem rather
/// than a hard-coded rule, so every valid split is enumerated and scored. For
/// the sizes involved that is cheap: the worst case in range, ten players into
/// two pods of five, is 126 distinct splits.
abstract final class PodBuilder {
  /// Smallest and largest pod a split may produce.
  ///
  /// A pod of three is acceptable, but only alongside a pod of four — seven
  /// players split 4+3. Splitting into nothing but threes is not offered.
  static const minPodSize = 3;
  static const maxPodSize = 5;

  /// Up to this many players stay at one table rather than splitting.
  static const singleTableUpTo = 6;

  /// Default pod sizes for a given player count.
  ///
  ///     3–6  one pod
  ///     7    4 + 3
  ///     8    4 + 4
  ///     9    5 + 4
  ///     10   5 + 5
  ///
  /// Above that the same rule keeps applying: the fewest pods that hold at
  /// most five each, filled as evenly as possible. Because sizes never differ
  /// by more than one, a pod of three only ever appears next to a pod of four.
  static List<int> podSizes(int playerCount, {int? podCount}) {
    if (playerCount <= 0) return const [];

    // An explicit override is the user's call, so it is honoured as given.
    if (podCount != null) return _distribute(playerCount, podCount);

    if (playerCount <= singleTableUpTo) return [playerCount];

    return _distribute(playerCount, (playerCount / maxPodSize).ceil());
  }

  static List<int> _distribute(int playerCount, int count) {
    if (count <= 1) return [playerCount];
    final base = playerCount ~/ count;
    final remainder = playerCount % count;
    // Larger pods first, so 9 into 2 gives [5, 4] rather than [4, 5].
    return [for (var i = 0; i < count; i++) base + (i < remainder ? 1 : 0)];
  }

  /// Pod counts the user may choose between.
  ///
  /// Every pod must hold three to five players, and an all-threes split is
  /// excluded because a pod of three is only acceptable beside a pod of four.
  static List<int> validPodCounts(int playerCount) => [
    // A single table is always an option for a group small enough to be one.
    if (playerCount <= singleTableUpTo) 1,
    for (var count = 2; count <= playerCount ~/ minPodSize; count++)
      if (count * minPodSize <= playerCount &&
          playerCount <= count * maxPodSize &&
          // n == 3 * count means every pod would be a three.
          playerCount != count * minPodSize)
        count,
  ];

  /// Every distinct way to split [players] into pods of the given sizes.
  ///
  /// Splits that differ only by swapping two equally sized pods are treated as
  /// the same assignment, which roughly halves the search for even splits.
  static List<List<List<int>>> enumerateSplits(
    int playerCount,
    List<int> sizes,
  ) {
    final results = <List<List<int>>>[];
    final indices = List.generate(playerCount, (i) => i);

    void recurse(List<int> remaining, int sizeIndex, List<List<int>> acc) {
      if (sizeIndex == sizes.length) {
        results.add([for (final pod in acc) List<int>.from(pod)]);
        return;
      }

      final size = sizes[sizeIndex];

      // Pinning the lowest remaining player to the current pod removes the
      // duplicate that comes from relabelling pods of equal size.
      final mustInclude = remaining.first;
      final rest = remaining.sublist(1);

      void choose(int start, List<int> picked) {
        if (picked.length == size - 1) {
          final pod = [mustInclude, ...picked];
          final left = [
            for (final r in remaining)
              if (!pod.contains(r)) r,
          ];
          acc.add(pod);
          recurse(left, sizeIndex + 1, acc);
          acc.removeLast();
          return;
        }
        for (var i = start; i < rest.length; i++) {
          choose(i + 1, [...picked, rest[i]]);
        }
      }

      choose(0, const []);
    }

    recurse(indices, 0, []);
    return results;
  }

  /// Scores one candidate assignment.
  static PodScore score(List<Pod> pods, PodMode mode, MatchupHistory history) {
    final power = _powerBalance(pods);
    final tier = _powerTiering(pods);
    final color = _colorDiversity(pods);
    final archetype = _archetypeDiversity(pods);
    final fresh = _freshMatchups(pods, history);
    final interaction = _interactionCoverage(pods);
    final playerBalance = _playerBalance(pods);

    final weights = _weights[mode] ?? const {};
    final components = {
      'power': power,
      'tier': tier,
      'color': color,
      'archetype': archetype,
      'fresh': fresh,
      'interaction': interaction,
      'playerBalance': playerBalance,
    };

    var weighted = 0.0;
    var totalWeight = 0.0;
    for (final entry in weights.entries) {
      weighted += components[entry.key]! * entry.value;
      totalWeight += entry.value;
    }

    return PodScore(
      powerBalance: power,
      powerTiering: tier,
      colorDiversity: color,
      archetypeDiversity: archetype,
      freshMatchups: fresh,
      interactionCoverage: interaction,
      playerBalance: playerBalance,
      // Random has no weights, so every assignment ties and the shuffle
      // decides — which is exactly what "Random" should mean.
      total: totalWeight == 0 ? 0 : weighted / totalWeight,
    );
  }

  /// Builds ranked assignments, best first.
  ///
  /// Returns several so "REBUILD PODS" can offer the next-best split rather
  /// than recomputing the same answer.
  static List<PodAssignment> build({
    required List<DeckProfile> players,
    required PodMode mode,
    MatchupHistory history = const {},
    int? podCount,
    int limit = 12,
    Random? random,
  }) {
    if (players.length < 2) return const [];

    final sizes = podSizes(players.length, podCount: podCount);
    if (sizes.length == 1) {
      final single = [Pod(players)];
      return [PodAssignment(pods: single, score: score(single, mode, history))];
    }

    final rng = random ?? Random();
    // Shuffling first means ties break differently each time, so pressing
    // rebuild on an unwinnable tie still moves people around.
    final shuffled = [...players]..shuffle(rng);

    final splits = enumerateSplits(shuffled.length, sizes);
    final scored = <PodAssignment>[];

    for (final split in splits) {
      final pods = [
        for (final podIndices in split)
          Pod([for (final i in podIndices) shuffled[i]]),
      ];
      scored.add(PodAssignment(pods: pods, score: score(pods, mode, history)));
    }

    scored.sort((a, b) => b.score.total.compareTo(a.score.total));
    return scored.take(limit).toList();
  }

  // ---- Scoring components -------------------------------------------------

  /// 1 when every pod has the same total power; falls away as they diverge.
  static double _powerBalance(List<Pod> pods) {
    if (pods.length < 2) return 1;
    final averages = [for (final p in pods) p.averagePower];
    final spread = averages.reduce(max) - averages.reduce(min);
    // A two-point gap in average power is a badly unbalanced table.
    return (1 - spread / 4).clamp(0, 1);
  }

  /// 1 when every pod's members sit at the same power level as each other.
  ///
  /// Measured as the average spread *within* each pod rather than between
  /// them. Minimising it necessarily separates the tiers: the only way for
  /// every pod to be internally consistent is for the strong decks to end up
  /// together and the weak ones together.
  ///
  /// Uses *variance* rather than standard deviation, which matters more than
  /// it looks. Averaging standard deviations scores `{10,10,9,3} + {5,5,5,5}`
  /// exactly the same as `{10,10,9,5} + {5,5,5,3}`, so there is nothing
  /// pulling the odd deck out of the top table. Squaring makes one badly
  /// placed outlier cost more than several small differences, which is the
  /// whole point — it is the same reason clustering minimises squared error.
  static double _powerTiering(List<Pod> pods) {
    if (pods.length < 2) return 1;

    var total = 0.0;
    var counted = 0;
    for (final pod in pods) {
      if (pod.members.length < 2) continue;
      final powers = [for (final m in pod.members) m.effectivePower];
      final mean = powers.reduce((a, b) => a + b) / powers.length;
      total +=
          powers.map((p) => (p - mean) * (p - mean)).reduce((a, b) => a + b) /
          powers.length;
      counted++;
    }
    if (counted == 0) return 1;

    // Variance 9 is a standard deviation of 3: a table where a precon is
    // sitting across from a tuned list, which is what this mode exists to
    // avoid.
    return (1 - (total / counted) / 9).clamp(0, 1);
  }

  /// Rewards pods whose members bring different colours.
  ///
  /// Silent when nobody has recorded a colour identity: an unrated group would
  /// otherwise be told its colour diversity is "very poor", which is a
  /// statement about missing data rather than about the pods.
  static double _colorDiversity(List<Pod> pods) {
    if (pods.isEmpty) return 1;
    final anyRecorded = pods.any(
      (p) => p.members.any((m) => m.colorIdentity.isNotEmpty),
    );
    if (!anyRecorded) return 1;

    var total = 0.0;
    for (final pod in pods) {
      if (pod.members.length < 2) {
        total += 1;
        continue;
      }
      // Average pairwise difference in colour identity.
      var pairs = 0;
      var distance = 0.0;
      for (var i = 0; i < pod.members.length; i++) {
        for (var j = i + 1; j < pod.members.length; j++) {
          final a = pod.members[i].colorIdentity;
          final b = pod.members[j].colorIdentity;
          final union = {...a, ...b};
          // A pair with nothing recorded says nothing either way, so it is
          // skipped rather than counted as identical.
          if (union.isEmpty) continue;
          distance += 1 - (a.intersection(b).length / union.length);
          pairs++;
        }
      }
      total += pairs == 0 ? 1 : distance / pairs;
    }
    return (total / pods.length).clamp(0, 1);
  }

  /// Penalises repeated archetypes inside a pod — the "four graveyard decks"
  /// case the brief calls out by name.
  static double _archetypeDiversity(List<Pod> pods) {
    if (pods.isEmpty) return 1;
    var total = 0.0;
    for (final pod in pods) {
      final tagged = pod.members.where((m) => m.archetypes.isNotEmpty).toList();
      if (tagged.length < 2 || pod.members.length < 2) {
        total += 1;
        continue;
      }
      final counts = <DeckArchetype, int>{};
      for (final m in tagged) {
        for (final a in m.archetypes) {
          counts[a] = (counts[a] ?? 0) + 1;
        }
      }
      // How concentrated is the most common archetype across the *whole* pod?
      //
      // Measured against every seat, not just the tagged ones: two graveyard
      // decks among six players is mild, but dividing by the tagged count
      // alone would report it as total concentration.
      final worst = counts.values.reduce(max);
      total += (1 - (worst - 1) / (pod.members.length - 1)).clamp(0, 1);
    }
    return (total / pods.length).clamp(0, 1);
  }

  /// Rewards pods whose members have played each other least.
  static double _freshMatchups(List<Pod> pods, MatchupHistory history) {
    if (history.isEmpty) return 1;
    final maxSeen = history.values.fold(0, max);
    if (maxSeen == 0) return 1;

    var pairs = 0;
    var repeatLoad = 0.0;
    for (final pod in pods) {
      for (var i = 0; i < pod.members.length; i++) {
        for (var j = i + 1; j < pod.members.length; j++) {
          final seen =
              history[matchupKey(
                pod.members[i].playerId,
                pod.members[j].playerId,
              )] ??
              0;
          repeatLoad += seen / maxSeen;
          pairs++;
        }
      }
    }
    return pairs == 0 ? 1 : (1 - repeatLoad / pairs).clamp(0, 1);
  }

  /// Rewards pods that can answer things — creatures, artifacts, graveyards,
  /// boards and the stack.
  ///
  /// A pod where nobody has filled anything in counts as unknown rather than
  /// as defenceless. Otherwise one player recording a single removal spell
  /// drags the whole table's rating down, which says more about how much the
  /// group has typed in than about the pods.
  static double _interactionCoverage(List<Pod> pods) {
    if (pods.isEmpty) return 1;

    var total = 0.0;
    for (final pod in pods) {
      final anyRecorded = pod.members.any((m) => m.interaction.isNotEmpty);
      total += anyRecorded
          ? pod.interaction.length / InteractionType.values.length
          : 1;
    }
    return (total / pods.length).clamp(0, 1);
  }

  /// Keeps historically strong players from stacking into one pod.
  static double _playerBalance(List<Pod> pods) {
    if (pods.length < 2) return 1;
    final anyHistory = pods.any((p) => p.members.any((m) => m.gamesPlayed > 0));
    if (!anyHistory) return 1;

    final averages = [
      for (final pod in pods)
        pod.members.isEmpty
            ? 0.0
            : pod.members.fold(0.0, (s, m) => s + m.winRate) /
                  pod.members.length,
    ];
    final spread = averages.reduce(max) - averages.reduce(min);
    // A 40-point gap in average win rate is a thoroughly lopsided table.
    return (1 - spread / 0.4).clamp(0, 1);
  }
}

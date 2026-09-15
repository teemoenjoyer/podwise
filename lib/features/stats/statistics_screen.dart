import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../domain/game_timer.dart';
import '../../domain/player_stats.dart';
import '../../state/providers.dart';

/// Per-player statistics across every saved game.
final playerStatsProvider = FutureProvider<List<PlayerStats>>((ref) async {
  final db = ref.watch(databaseProvider);
  // Depend on history so finishing a game refreshes the numbers.
  ref.watch(gameHistoryProvider);

  final raw = await db.playerStatistics();
  final names = {for (final acc in raw.values) acc.profileId: acc.name};

  final stats = [
    for (final acc in raw.values)
      PlayerStats(
        profileId: acc.profileId,
        name: acc.name,
        gamesPlayed: acc.games,
        wins: acc.wins,
        totalPosition: acc.totalPosition,
        totalDuration: acc.totalDuration,
        opponentCounts: {
          for (final e in acc.opponents.entries)
            names[e.key] ?? 'Someone': e.value,
        },
      ),
  ]..sort((a, b) => b.gamesPlayed.compareTo(a.gamesPlayed));

  return stats;
});

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(playerStatsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: switch (stats) {
        AsyncData(:final value) when value.isEmpty => const _Empty(),
        AsyncData(:final value) => ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          itemCount: value.length,
          itemBuilder: (_, i) => _PlayerCard(stats: value[i]),
        ),
        AsyncError(:final error) => Center(child: Text('$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({required this.stats});
  final PlayerStats stats;

  @override
  Widget build(BuildContext context) {
    final opponent = stats.mostCommonOpponent;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PodWiseColors.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  stats.name,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                '${stats.gamesPlayed} '
                'game${stats.gamesPlayed == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Stat(
                label: 'WIN RATE',
                value: '${(stats.winRate * 100).round()}%',
                // Below a handful of games a win rate is mostly noise, so it
                // is shown greyed with a caveat rather than presented as fact.
                muted: !stats.hasMeaningfulSample,
              ),
              _Stat(label: 'WINS', value: '${stats.wins}'),
              _Stat(
                label: 'AVG FINISH',
                value: stats.averagePosition == null
                    ? '—'
                    : stats.averagePosition!.toStringAsFixed(1),
              ),
              _Stat(
                label: 'AVG GAME',
                value: stats.averageDuration == null
                    ? '—'
                    : GameTimer.format(stats.averageDuration!),
              ),
            ],
          ),
          if (!stats.hasMeaningfulSample) ...[
            const SizedBox(height: 10),
            Text(
              'Only ${stats.gamesPlayed} '
              'game${stats.gamesPlayed == 1 ? '' : 's'} so far — these numbers '
              'will swing a lot until there are '
              '${PlayerStats.meaningfulSampleSize}.',
              style: TextStyle(
                fontSize: 11,
                height: 1.4,
                color: PodWiseColors.caution.withValues(alpha: 0.8),
              ),
            ),
          ],
          if (opponent != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.people_outline_rounded,
                  size: 14,
                  color: Colors.white.withValues(alpha: 0.4),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Most often against ${opponent.key} '
                    '(${opponent.value} '
                    'game${opponent.value == 1 ? '' : 's'})',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.muted = false});

  final String label;
  final String value;
  final bool muted;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w600,
            color: muted ? Colors.white.withValues(alpha: 0.45) : Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            letterSpacing: 1.2,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ],
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.insights_rounded,
            size: 46,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'No finished games yet.\n'
            'Statistics appear once you have played and saved one.',
            textAlign: TextAlign.center,
            style: TextStyle(
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    ),
  );
}

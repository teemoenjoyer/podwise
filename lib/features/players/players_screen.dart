import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../domain/models.dart';
import '../../domain/player_stats.dart';
import '../../domain/pod.dart';
import '../../state/pod_providers.dart';
import '../stats/statistics_screen.dart';
import 'player_dialogs.dart';
import 'player_detail_screen.dart';

/// Everything known about one player, gathered for the list.
typedef PlayerOverview = ({
  PlayerProfile player,
  List<DeckProfile> decks,
  PlayerStats? stats,
});

/// Saved players with their deck library and record.
final playerOverviewsProvider = FutureProvider<List<PlayerOverview>>((
  ref,
) async {
  final roster = await ref.watch(playerDecksProvider.future);
  final stats = await ref.watch(playerStatsProvider.future);
  final byId = {for (final s in stats) s.profileId: s};

  final overviews =
      [
        for (final entry in roster)
          (
            player: entry.player,
            // Placeholders exist only to keep the Pod Builder working; a
            // player's library should read as empty until they save a deck.
            decks: [
              for (final deck in entry.decks)
                if (deck.isSaved) deck,
            ],
            stats: byId[entry.player.id],
          ),
      ]..sort((a, b) {
        // Most active first; the regulars are who you usually want.
        final games = (b.stats?.gamesPlayed ?? 0).compareTo(
          a.stats?.gamesPlayed ?? 0,
        );
        return games != 0 ? games : a.player.name.compareTo(b.player.name);
      });

  return overviews;
});

class PlayersScreen extends ConsumerWidget {
  const PlayersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviews = ref.watch(playerOverviewsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Players'),
        actions: [
          // The group side of the same numbers. A player's own page answers
          // "how is Dave doing?"; this answers "how does the group compare?".
          IconButton(
            tooltip: 'Statistics',
            icon: const Icon(Icons.leaderboard_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const StatisticsScreen(),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Add player',
            icon: const Icon(Icons.person_add_alt_1_rounded),
            onPressed: () => showAddPlayerDialog(context, ref),
          ),
        ],
      ),
      body: switch (overviews) {
        AsyncData(:final value) when value.isEmpty => _Empty(
          onAdd: () => showAddPlayerDialog(context, ref),
        ),
        AsyncData(:final value) => ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          itemCount: value.length,
          itemBuilder: (_, i) => _PlayerCard(
            overview: value[i],
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) =>
                    PlayerDetailScreen(playerId: value[i].player.id),
              ),
            ),
          ),
        ),
        AsyncError(:final error) => Center(child: Text('$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({required this.overview, required this.onTap});

  final PlayerOverview overview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final player = overview.player;
    final decks = overview.decks;
    final stats = overview.stats;
    final colour =
        PodWiseColors.seats[player.colorIndex % PodWiseColors.seats.length];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: PodWiseColors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: colour.withValues(alpha: 0.25),
                  child: Text(
                    player.initials,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: colour,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        player.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(
                            decks.isEmpty
                                ? Icons.help_outline_rounded
                                : Icons.style_rounded,
                            size: 12,
                            color: decks.isEmpty
                                ? Colors.white.withValues(alpha: 0.35)
                                : PodWiseColors.accent,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              _decksLine(decks),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: decks.isEmpty
                                    ? Colors.white.withValues(alpha: 0.35)
                                    : Colors.white.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      stats == null || stats.gamesPlayed == 0
                          ? '—'
                          : '${(stats.winRate * 100).round()}%',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: stats?.hasMeaningfulSample ?? false
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                    Text(
                      '${stats?.gamesPlayed ?? 0} '
                      'game${(stats?.gamesPlayed ?? 0) == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// One deck reads as itself; several read as a count led by the most recent,
  /// which is the one they are most likely bringing.
  static String _decksLine(List<DeckProfile> decks) => switch (decks.length) {
    0 => 'No decks saved yet',
    1 => decks.first.displayName,
    _ => '${decks.length} decks  ·  ${decks.first.displayName}',
  };
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.groups_rounded,
            size: 46,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'No players saved yet.\n'
            'Add your playgroup once and reuse them.',
            textAlign: TextAlign.center,
            style: TextStyle(
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 24),
          // An empty list with nothing but an app-bar icon is easy to walk
          // away from, so the first player gets an obvious way in.
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('ADD PLAYER'),
          ),
        ],
      ),
    ),
  );
}

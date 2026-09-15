import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';
import '../game/game_summary_screen.dart' show formatDuration;

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(gameHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Game history')),
      body: switch (history) {
        AsyncData(:final value) when value.isEmpty => const _Empty(),
        AsyncData(:final value) => ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          itemCount: value.length,
          itemBuilder: (_, i) => _GameCard(record: value[i]),
        ),
        AsyncError(:final error) => Center(child: Text('Error: $error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
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
            Icons.history_rounded,
            size: 48,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            'No games saved yet.\nFinish a game and it will appear here.',
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

class _GameCard extends StatelessWidget {
  const _GameCard({required this.record});
  final GameRecord record;

  @override
  Widget build(BuildContext context) {
    final winner = record.winner;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PodWiseColors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                DateFormat('d MMM yyyy  ·  HH:mm').format(record.startedAt),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
              const Spacer(),
              Text(
                formatDuration(record.duration),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.45),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (winner != null)
            Row(
              children: [
                const Text('🏆', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(
                  winner.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          else
            Text(
              'No winner recorded',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final r in record.results)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: PodWiseColors.surfaceHigh,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${r.name}  ${r.finalLife}',
                    style: TextStyle(
                      fontSize: 12,
                      color: r.won
                          ? PodWiseColors.accent
                          : Colors.white.withValues(alpha: 0.7),
                      fontWeight: r.won ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

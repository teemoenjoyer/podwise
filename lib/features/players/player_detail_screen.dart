import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../domain/commander.dart';
import '../../domain/game_timer.dart';
import '../../domain/models.dart';
import '../../domain/player_stats.dart';
import '../../domain/pod.dart';
import '../../state/pod_providers.dart';
import '../commander/commander_art.dart';
import '../commander/commander_search_sheet.dart';
import '../pods/deck_profile_sheet.dart';
import 'player_dialogs.dart';
import 'players_screen.dart';

/// One player: the decks they own, and how they have done.
class PlayerDetailScreen extends ConsumerWidget {
  const PlayerDetailScreen({super.key, required this.playerId});

  final String playerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overviews = ref.watch(playerOverviewsProvider);

    return switch (overviews) {
      AsyncData(:final value) => _build(
        context,
        ref,
        value.where((o) => o.player.id == playerId).firstOrNull,
      ),
      AsyncError(:final error) => Scaffold(body: Center(child: Text('$error'))),
      _ => const Scaffold(body: Center(child: CircularProgressIndicator())),
    };
  }

  Widget _build(BuildContext context, WidgetRef ref, PlayerOverview? overview) {
    if (overview == null) {
      return const Scaffold(body: Center(child: Text('Player not found')));
    }

    final player = overview.player;
    final decks = overview.decks;
    final stats = overview.stats;

    return Scaffold(
      appBar: AppBar(
        title: Text(player.name),
        actions: [
          PopupMenuButton<_PlayerAction>(
            tooltip: 'Player options',
            onSelected: (action) => switch (action) {
              _PlayerAction.rename => showRenamePlayerDialog(
                context,
                ref,
                player,
              ),
              _PlayerAction.remove => _remove(context, ref, player, decks),
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: _PlayerAction.rename, child: Text('Rename')),
              PopupMenuItem(
                value: _PlayerAction.remove,
                child: Text('Remove player'),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _Label('DECKS  ·  ${decks.length}'),
          if (decks.isEmpty)
            const _NoDecks()
          else
            for (final deck in decks)
              _DeckCard(deck: deck, onTap: () => _editDeck(context, deck)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _addDeck(context, ref, player),
            icon: const Icon(Icons.add_rounded),
            label: const Text('ADD DECK'),
          ),

          const _Label('RECORD'),
          if (stats == null || stats.gamesPlayed == 0)
            const _NoGames()
          else ...[
            _StatGrid(stats: stats),
            if (!stats.hasMeaningfulSample)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Only ${stats.gamesPlayed} '
                  'game${stats.gamesPlayed == 1 ? '' : 's'} recorded — these '
                  'will move a lot until there are '
                  '${PlayerStats.meaningfulSampleSize}.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: PodWiseColors.caution.withValues(alpha: 0.8),
                  ),
                ),
              ),
            if (stats.opponentCounts.isNotEmpty) ...[
              const _Label('PLAYS AGAINST'),
              _OpponentList(counts: stats.opponentCounts),
            ],
          ],
        ],
      ),
    );
  }

  /// Removes the player, then leaves — this screen is about them, and there
  /// is nothing left here once they are gone.
  Future<void> _remove(
    BuildContext context,
    WidgetRef ref,
    PlayerProfile player,
    List<DeckProfile> decks,
  ) async {
    final removed = await showRemovePlayerDialog(
      context,
      ref,
      player,
      deckCount: decks.length,
    );
    if (removed && context.mounted) Navigator.of(context).pop();
  }

  void _editDeck(BuildContext context, DeckProfile deck) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: PodWiseColors.surfaceRaised,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => DeckProfileSheet(profile: deck),
    );
  }

  /// Adds a deck by its commander, then opens the editor so it can be rated
  /// while the player is still thinking about it.
  Future<void> _addDeck(
    BuildContext context,
    WidgetRef ref,
    PlayerProfile player,
  ) async {
    final commanders = await Navigator.of(context).push<CommanderSet>(
      MaterialPageRoute(
        builder: (_) => CommanderSearchScreen(playerName: player.name),
      ),
    );
    if (commanders == null || commanders.isEmpty) return;

    // Goes through the same matching used at game start, so re-adding a
    // commander they already own reopens that deck instead of duplicating it.
    final deck = await ref
        .read(deckEditorProvider)
        .deckForCommanders(player, commanders);

    if (deck == null || !context.mounted) return;
    _editDeck(context, deck);
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 24, 0, 10),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
        color: Colors.white.withValues(alpha: 0.45),
      ),
    ),
  );
}

class _DeckCard extends StatelessWidget {
  const _DeckCard({required this.deck, required this.onTap});

  final DeckProfile deck;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: PodWiseColors.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CommanderArt(
                      commanderIds: deck.commanderIds,
                      width: 44,
                      height: 32,
                      fallback: Icons.auto_awesome_rounded,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        deck.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.tune_rounded,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ],
                ),
                // The nickname replaces the commander in the heading, so the
                // commander still needs saying underneath.
                if (deck.deckName.isNotEmpty && deck.commanderName.isNotEmpty)
                  Padding(
                    // Indented to clear the art, so it lines up under the
                    // nickname rather than under the thumbnail.
                    padding: const EdgeInsets.only(top: 4, left: 54),
                    child: Text(
                      deck.commanderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _Chip(
                      label: 'Power ${deck.power}',
                      // The self-corrected figure only differs once this deck
                      // has results of its own.
                      detail: deck.effectivePower != deck.power.toDouble()
                          ? 'plays like '
                                '${deck.effectivePower.toStringAsFixed(1)}'
                          : null,
                    ),
                    if (deck.colorIdentity.isNotEmpty)
                      _Chip(label: deck.colorIdentityString),
                    _Chip(
                      label: deck.gamesPlayed == 0
                          ? 'No games yet'
                          : '${deck.wins}/${deck.gamesPlayed}  ·  '
                                '${(deck.winRate * 100).round()}%',
                    ),
                  ],
                ),
                if (deck.archetypes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final a in deck.archetypes) _Chip(label: a.label),
                    ],
                  ),
                ],
                if (deck.interaction.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Answers: ${deck.interaction.map((i) => i.label).join(', ')}',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.detail});
  final String label;
  final String? detail;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: PodWiseColors.surfaceHigh,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      detail == null ? label : '$label  ·  $detail',
      style: const TextStyle(fontSize: 12),
    ),
  );
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.stats});
  final PlayerStats stats;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PodWiseColors.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _Stat(label: 'GAMES', value: '${stats.gamesPlayed}'),
          _Stat(label: 'WINS', value: '${stats.wins}'),
          _Stat(
            label: 'WIN RATE',
            value: '${(stats.winRate * 100).round()}%',
            muted: !stats.hasMeaningfulSample,
          ),
          _Stat(
            label: 'AVG FINISH',
            value: stats.averagePosition?.toStringAsFixed(1) ?? '—',
          ),
          _Stat(
            label: 'AVG GAME',
            value: stats.averageDuration == null
                ? '—'
                : GameTimer.format(stats.averageDuration!),
          ),
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
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: muted
                  ? Colors.white.withValues(alpha: 0.45)
                  : Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 8,
            letterSpacing: 1,
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ],
    ),
  );
}

class _OpponentList extends StatelessWidget {
  const _OpponentList({required this.counts});
  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final most = sorted.first.value;

    return Column(
      children: [
        for (final entry in sorted)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    entry.key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: most == 0 ? 0 : entry.value / most,
                      minHeight: 7,
                      backgroundColor: PodWiseColors.surfaceHigh,
                      valueColor: AlwaysStoppedAnimation(
                        PodWiseColors.accent.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 34,
                  child: Text(
                    '${entry.value}',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _NoDecks extends StatelessWidget {
  const _NoDecks();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: PodWiseColors.surfaceRaised,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      'No decks yet. Add one here, or just pick a commander when starting a '
      'game and it will be saved as a deck.',
      style: TextStyle(
        fontSize: 13,
        height: 1.4,
        color: Colors.white.withValues(alpha: 0.5),
      ),
    ),
  );
}

class _NoGames extends StatelessWidget {
  const _NoGames();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: PodWiseColors.surfaceRaised,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      'No finished games yet. Their record appears here once they have '
      'played one.',
      style: TextStyle(
        fontSize: 13,
        height: 1.4,
        color: Colors.white.withValues(alpha: 0.5),
      ),
    ),
  );
}

/// What the overflow menu on a player's page offers.
enum _PlayerAction { rename, remove }

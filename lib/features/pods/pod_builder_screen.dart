import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../domain/pod.dart';
import '../../domain/pod_builder.dart';
import '../../state/pod_providers.dart';
import '../../state/providers.dart';
import '../../state/transfer_providers.dart';
import '../transfer/show_code_screen.dart';
import '../setup/new_game_screen.dart';
import 'deck_profile_sheet.dart';
import 'pod_result_view.dart';

/// Pod Builder: pick who's playing, pick a mode, press the button.
///
/// This is the app's differentiator, so it gets a screen of its own rather
/// than living inside the new-game flow.
class PodBuilderScreen extends ConsumerWidget {
  const PodBuilderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(podSessionProvider);
    final notifier = ref.read(podSessionProvider.notifier);
    final roster = ref.watch(playerDecksProvider);

    // Once pods exist, they take over the screen.
    if (session.current != null) {
      return PodResultView(
        assignment: session.current!,
        mode: session.mode,
        onRebuild: notifier.rebuild,
        onBack: () => notifier.setMode(session.mode),
        onStart: (pod) => _startPod(context, ref, pod, session),
        onSend: (pod) => _sendPod(context, ref, pod),
        rouletteDecks: session.rouletteDecks,
        onReroll: session.mode.swapsDecks ? notifier.rerollDeck : null,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Build pods'),
        actions: [
          IconButton(
            tooltip: 'Start over',
            onPressed: notifier.clear,
            icon: const Icon(Icons.restart_alt_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: switch (roster) {
                AsyncData(:final value) when value.length < 2 =>
                  const _NotEnoughPlayers(),
                AsyncData(:final value) => ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    const _Label('MODE'),
                    const SizedBox(height: 10),
                    _ModePicker(
                      selected: session.mode,
                      onChanged: notifier.setMode,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      session.mode.description,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(height: 28),
                    _Label(
                      'PLAYERS  ·  ${session.selectedIds.length} SELECTED',
                    ),
                    const SizedBox(height: 10),
                    for (final entry in value)
                      _PlayerRow(
                        entry: entry,
                        deck: session.deckFor(entry),
                        selected: session.selectedIds.contains(entry.player.id),
                        onTap: () => notifier.toggle(entry.player.id),
                        onChooseDeck: (deckId) =>
                            notifier.chooseDeck(entry.player.id, deckId),
                        onEdit: () => showModalBottomSheet<void>(
                          context: context,
                          backgroundColor: PodWiseColors.surfaceRaised,
                          showDragHandle: true,
                          isScrollControlled: true,
                          builder: (_) =>
                              DeckProfileSheet(profile: session.deckFor(entry)),
                        ),
                      ),

                    const SizedBox(height: 20),
                    // Shows itself only when there is genuinely more than one
                    // legal split to choose between.
                    _PodCountPicker(
                      playerCount: session.selectedIds.length,
                      selected: session.podCount,
                      onChanged: notifier.setPodCount,
                    ),
                  ],
                ),
                AsyncError(:final error) => Center(
                  child: Text('Could not load players: $error'),
                ),
                _ => const Center(child: CircularProgressIndicator()),
              },
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: FilledButton(
                onPressed: session.canBuild && !session.building
                    ? () {
                        HapticFeedback.mediumImpact();
                        notifier.buildPods();
                      }
                    : null,
                child: session.building
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        session.canBuild
                            ? 'BUILD PODS'
                            : 'SELECT AT LEAST 2 PLAYERS',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Hands a pod to another phone, which keeps score for it and gives the
  /// result back as a code.
  Future<void> _sendPod(BuildContext context, WidgetRef ref, Pod pod) async {
    final payload = await ref.read(transferServiceProvider).packPod(pod);
    if (!context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ShowCodeScreen(
          payload: payload,
          title: 'Send this pod',
          instruction:
              'Have them open PodWise, tap SCAN, and point their camera at '
              'this. When their game finishes they will have a code to show '
              'you, which puts the result into your history.',
        ),
      ),
    );
  }

  /// Takes a built pod to the New Game screen with its seats and decks already
  /// filled in.
  ///
  /// It stops there rather than starting immediately because starting life is
  /// still an open question — Brawl and house rules are not 40 — and because
  /// the table should get one last look at the seats before play begins.
  void _startPod(
    BuildContext context,
    WidgetRef ref,
    Pod pod,
    PodSession session,
  ) {
    final profiles = ref.read(playerProfilesProvider).valueOrNull ?? const [];
    final byId = {for (final profile in profiles) profile.id: profile};
    final roulette = session.mode.swapsDecks;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NewGameScreen(
          initialPlayers: [
            // A member whose profile has gone missing is dropped rather than
            // seated as a blank.
            for (final member in pod.members) ?byId[member.playerId],
          ],
          // On a roulette night they are playing the deck they were dealt,
          // not their own.
          initialDecks: {
            for (final member in pod.members)
              if (roulette)
                if (session.rouletteDecks[member.playerId] case final dealt?)
                  member.playerId: dealt
                else
                  ...{}
              else if (member.isSaved)
                member.playerId: member,
          },
          deckRoulette: roulette,
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: 2,
      color: Colors.white.withValues(alpha: 0.45),
    ),
  );
}

class _ModePicker extends StatelessWidget {
  const _ModePicker({required this.selected, required this.onChanged});

  final PodMode selected;
  final ValueChanged<PodMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final mode in PodMode.values)
          ChoiceChip(
            label: Text(mode.label),
            selected: selected == mode,
            onSelected: (_) => onChanged(mode),
            labelStyle: TextStyle(
              fontSize: 13,
              fontWeight: selected == mode ? FontWeight.w700 : FontWeight.w400,
              color: selected == mode ? Colors.black : Colors.white70,
            ),
            selectedColor: PodWiseColors.accent,
            backgroundColor: PodWiseColors.surfaceRaised,
            side: BorderSide.none,
            showCheckmark: false,
          ),
      ],
    );
  }
}

class _PodCountPicker extends StatelessWidget {
  const _PodCountPicker({
    required this.playerCount,
    required this.selected,
    required this.onChanged,
  });

  final int playerCount;
  final int? selected;
  final ValueChanged<int?> onChanged;

  @override
  Widget build(BuildContext context) {
    // Only offer counts that keep every pod to four or five players.
    final options = PodBuilder.validPodCounts(playerCount);
    if (options.length < 2) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label('NUMBER OF PODS'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Auto'),
              selected: selected == null,
              onSelected: (_) => onChanged(null),
              selectedColor: PodWiseColors.accent,
              backgroundColor: PodWiseColors.surfaceRaised,
              side: BorderSide.none,
              showCheckmark: false,
              labelStyle: TextStyle(
                color: selected == null ? Colors.black : Colors.white70,
              ),
            ),
            for (final n in options)
              ChoiceChip(
                label: Text('$n'),
                selected: selected == n,
                onSelected: (_) => onChanged(n),
                selectedColor: PodWiseColors.accent,
                backgroundColor: PodWiseColors.surfaceRaised,
                side: BorderSide.none,
                showCheckmark: false,
                labelStyle: TextStyle(
                  color: selected == n ? Colors.black : Colors.white70,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({
    required this.entry,
    required this.deck,
    required this.selected,
    required this.onTap,
    required this.onChooseDeck,
    required this.onEdit,
  });

  final PlayerDecks entry;

  /// The deck this player is bringing — the one being balanced.
  final DeckProfile deck;

  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<String> onChooseDeck;
  final VoidCallback onEdit;

  /// Only worth offering a choice when there is more than one deck to choose.
  bool get _canSwitch => entry.decks.length > 1;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? PodWiseColors.accent.withValues(alpha: 0.14)
            : PodWiseColors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
            child: Row(
              children: [
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  color: selected
                      ? PodWiseColors.accent
                      : Colors.white.withValues(alpha: 0.25),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.player.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      _DeckLine(
                        deck: deck,
                        canSwitch: _canSwitch,
                        onSwitch: () => _pickDeck(context),
                      ),
                    ],
                  ),
                ),
                _PowerPill(power: deck.effectivePower),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.tune_rounded, size: 20),
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDeck(BuildContext context) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: PodWiseColors.surfaceRaised,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                'Which deck is ${entry.player.name} bringing?',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (final option in entry.decks)
              ListTile(
                leading: Icon(
                  option.deckId == deck.deckId
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: option.deckId == deck.deckId
                      ? PodWiseColors.accent
                      : Colors.white.withValues(alpha: 0.35),
                ),
                title: Text(option.displayName),
                subtitle: Text(
                  'Power ${option.power}'
                  '${option.gamesPlayed == 0 ? '' : '  ·  '
                            '${(option.winRate * 100).round()}% over '
                            '${option.gamesPlayed}'}',
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () => Navigator.of(context).pop(option.deckId),
              ),
          ],
        ),
      ),
    );
    if (chosen != null) onChooseDeck(chosen);
  }
}

/// The deck line under a player's name, which doubles as the deck switcher.
class _DeckLine extends StatelessWidget {
  const _DeckLine({
    required this.deck,
    required this.canSwitch,
    required this.onSwitch,
  });

  final DeckProfile deck;
  final bool canSwitch;
  final VoidCallback onSwitch;

  @override
  Widget build(BuildContext context) {
    final text = _subtitle(deck);

    final label = Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11,
        color: deck.isRated
            ? Colors.white.withValues(alpha: 0.55)
            : PodWiseColors.caution.withValues(alpha: 0.8),
      ),
    );

    if (!canSwitch) return label;

    return GestureDetector(
      onTap: onSwitch,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Flexible(child: label),
          const SizedBox(width: 4),
          Icon(
            Icons.expand_more_rounded,
            size: 14,
            color: PodWiseColors.accent,
          ),
        ],
      ),
    );
  }

  static String _subtitle(DeckProfile d) {
    // A player with nothing saved has no deck to name yet.
    if (!d.isSaved) return 'Not rated yet — tap the slider to set power';

    // The deck's name leads even when it is unrated, so switching between two
    // unrated decks still shows which one is selected.
    final parts = [
      d.displayName,
      if (d.archetypes.isNotEmpty)
        d.archetypes.map((a) => a.label).take(2).join(', '),
      // Ahead of the record, because it is the part asking to be acted on and
      // so the part that must survive being truncated.
      if (!d.isRated) 'not rated',
      if (d.gamesPlayed > 0)
        '${(d.winRate * 100).round()}% over ${d.gamesPlayed}',
    ];
    return parts.join('  ·  ');
  }
}

class _PowerPill extends StatelessWidget {
  const _PowerPill({required this.power});
  final double power;

  @override
  Widget build(BuildContext context) {
    final rounded = power.round();
    final color = switch (rounded) {
      >= 8 => PodWiseColors.danger,
      >= 6 => PodWiseColors.caution,
      _ => PodWiseColors.healthy,
    };
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        '$rounded',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _NotEnoughPlayers extends StatelessWidget {
  const _NotEnoughPlayers();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.groups_rounded,
            size: 44,
            color: Colors.white.withValues(alpha: 0.22),
          ),
          const SizedBox(height: 16),
          Text(
            'Add some players first.\n'
            'The Pod Builder needs at least two people to split up.',
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../../domain/pod.dart';
import '../commander/commander_art.dart';

/// Shows the pods that were built, and why.
///
/// Section 6 of the brief is explicit that showing the lists alone is not
/// enough — the group should be able to see what the algorithm was optimising
/// for and disagree with it.
class PodResultView extends StatelessWidget {
  const PodResultView({
    super.key,
    required this.assignment,
    required this.mode,
    required this.onRebuild,
    required this.onBack,
    required this.onStart,
    required this.onSend,
    this.rouletteDecks = const {},
    this.onReroll,
  });

  final PodAssignment assignment;
  final PodMode mode;
  final VoidCallback onRebuild;
  final VoidCallback onBack;

  /// Takes a pod to the table. Only one pod can be played on this phone, so
  /// the choice belongs to each pod rather than to the screen.
  final ValueChanged<Pod> onStart;

  /// Hands a pod to somebody else's phone to keep score for.
  final ValueChanged<Pod> onSend;

  /// In Deck Roulette, the deck each player has been dealt, by player id.
  /// Empty in every other mode.
  final Map<String, DeckProfile> rouletteDecks;

  /// Deals one player a different deck.
  final ValueChanged<String>? onReroll;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          assignment.pods.length == 1
              ? 'One table'
              : '${assignment.pods.length} pods',
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: onBack,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                mode.label.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700,
                  color: PodWiseColors.accent,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  for (var i = 0; i < assignment.pods.length; i++)
                    _PodCard(
                      index: i,
                      pod: assignment.pods[i],
                      // With one table there is no ambiguity about which pod
                      // is being started, so it need not be numbered.
                      startLabel: assignment.pods.length == 1
                          ? 'START GAME'
                          : 'START POD ${i + 1}',
                      onStart: () => onStart(assignment.pods[i]),
                      onSend: () => onSend(assignment.pods[i]),
                      rouletteDecks: rouletteDecks,
                      onReroll: onReroll,
                    ),

                  const SizedBox(height: 16),
                  _WhyThesePods(
                    score: assignment.score,
                    mode: mode,
                    podCount: assignment.pods.length,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  onRebuild();
                },
                icon: const Icon(Icons.shuffle_rounded),
                label: const Text('REBUILD PODS'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PodCard extends StatelessWidget {
  const _PodCard({
    required this.index,
    required this.pod,
    required this.startLabel,
    required this.onStart,
    required this.onSend,
    required this.rouletteDecks,
    required this.onReroll,
  });

  final int index;
  final Pod pod;
  final String startLabel;
  final VoidCallback onStart;
  final VoidCallback onSend;
  final Map<String, DeckProfile> rouletteDecks;
  final ValueChanged<String>? onReroll;

  @override
  Widget build(BuildContext context) {
    final accent = PodWiseColors.seats[index % PodWiseColors.seats.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: PodWiseColors.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(15),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'POD ${index + 1}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: accent,
                  ),
                ),
                const Spacer(),
                Text(
                  '${pod.size} players  ·  avg power '
                  '${pod.averagePower.toStringAsFixed(1)}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          for (final member in pod.members)
            _MemberRow(
              member: member,
              dealt: rouletteDecks[member.playerId],
              roulette: onReroll != null,
              onReroll: onReroll == null
                  ? null
                  : () => onReroll!(member.playerId),
            ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(
              children: [
                // Only one pod can be tracked on this phone, so every other
                // pod needs somewhere to go.
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      onSend();
                    },
                    icon: const Icon(Icons.qr_code_2_rounded, size: 20),
                    label: const Text('SEND'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: accent.withValues(alpha: 0.22),
                      foregroundColor: accent,
                    ),
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      onStart();
                    },
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    label: Text(startLabel),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One player in a pod.
///
/// On a roulette night this shows the deck they have been handed and whose it
/// is, in place of their own deck and its power — that rating belongs to the
/// owner and says nothing about how a stranger will pilot the thing.
class _MemberRow extends StatelessWidget {
  const _MemberRow({
    required this.member,
    required this.dealt,
    required this.roulette,
    required this.onReroll,
  });

  final DeckProfile member;

  /// The deck they have been dealt. Null on a roulette night means the deal
  /// could not find them anything.
  final DeckProfile? dealt;

  final bool roulette;
  final VoidCallback? onReroll;

  @override
  Widget build(BuildContext context) {
    final stranded = roulette && dealt == null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          // The deck actually being played, which on a roulette night is
          // somebody else's — being handed a deck should show you what you
          // have been handed, not just name it.
          CommanderArt(
            commanderIds: (dealt ?? member).commanderIds,
            width: 40,
            height: 29,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.playerName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_subtitle.isNotEmpty)
                  Text(
                    _subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: stranded
                          ? PodWiseColors.caution.withValues(alpha: 0.9)
                          : Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
          if (roulette)
            IconButton(
              tooltip: 'Deal a different deck',
              visualDensity: VisualDensity.compact,
              onPressed: onReroll,
              icon: Icon(
                Icons.casino_rounded,
                size: 20,
                color: PodWiseColors.accent.withValues(alpha: 0.9),
              ),
            )
          else
            // Power is meaningless once the decks have been swapped around.
            Text(
              member.effectivePower.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
        ],
      ),
    );
  }

  String get _subtitle {
    if (roulette) {
      final deck = dealt;
      if (deck == null) return 'No spare deck to hand them';
      // Whose it is matters as much as what it is — half the fun is knowing
      // who has to watch you play it.
      return "${deck.displayName}  ·  ${deck.playerName}'s";
    }
    return [
      if (member.commanderName.isNotEmpty) member.commanderName,
      if (member.archetypes.isNotEmpty)
        member.archetypes.map((a) => a.label).take(2).join(', '),
    ].join('  ·  ');
  }
}

/// The explanation panel. Uses plain words and bars rather than raw numbers —
/// the point is for a table to glance at it and agree or argue.
class _WhyThesePods extends StatelessWidget {
  const _WhyThesePods({
    required this.score,
    required this.mode,
    required this.podCount,
  });

  final PodScore score;
  final PodMode mode;
  final int podCount;

  @override
  Widget build(BuildContext context) {
    // Nothing was balanced because nothing could be: everyone is at one table,
    // so there is no alternative arrangement to compare against. Grading
    // diversity here would be scoring a decision that was never made.
    if (podCount == 1) {
      return const _Note(
        icon: Icons.groups_rounded,
        text:
            'Everyone is playing together, so there was nothing to balance. '
            'Add more players to split into pods.',
      );
    }

    if (mode == PodMode.random) {
      return const _Note(
        icon: Icons.casino_rounded,
        text:
            'Pure random — no balancing was applied. '
            'Pick another mode if you want these pods weighed.',
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: PodWiseColors.surfaceRaised,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Why these pods?',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          // Competitive Balance is trying to do the opposite of evening power
          // out, so reporting "power balance" for it would grade a good split
          // as a bad one.
          if (mode == PodMode.competitiveBalance)
            _Metric(label: 'Power tiering', value: score.powerTiering)
          else
            _Metric(label: 'Power balance', value: score.powerBalance),
          _Metric(label: 'Strategy diversity', value: score.archetypeDiversity),
          _Metric(label: 'Colour diversity', value: score.colorDiversity),
          _Metric(
            label: 'Fresh matchups',
            value: score.freshMatchups,
            // Reads better as the thing people care about avoiding.
            invertedLabel: 'Repeat matchups',
          ),
          _Metric(label: 'Answers available', value: score.interactionCoverage),
          const SizedBox(height: 10),
          Text(
            'These are estimates from what the group has entered, not '
            'measurements. Rebuild if the table disagrees.',
            style: TextStyle(
              fontSize: 11,
              height: 1.4,
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Stands in for the metric list when there was nothing to weigh.
class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: PodWiseColors.surfaceRaised,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.4)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.invertedLabel});

  final String label;
  final double value;

  /// Shown instead of [label] when the score is poor, because "Repeat
  /// matchups: high" is clearer than "Fresh matchups: very poor".
  final String? invertedLabel;

  @override
  Widget build(BuildContext context) {
    final poor = value < 0.5;
    final color = switch (value) {
      >= 0.85 => PodWiseColors.healthy,
      >= 0.6 => PodWiseColors.accent,
      >= 0.4 => PodWiseColors.caution,
      _ => PodWiseColors.danger,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(
              poor && invertedLabel != null ? invertedLabel! : label,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value.clamp(0, 1),
                minHeight: 7,
                backgroundColor: PodWiseColors.surfaceHigh,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          SizedBox(
            width: 84,
            child: Text(
              PodScore.describe(value),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

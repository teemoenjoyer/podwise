import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../domain/commander.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';

/// Records commander damage dealt *to* one player.
///
/// Laid out as one row per opposing commander, because that is the unit the
/// rules care about: 21 from a single commander is lethal, 21 spread across
/// two is not.
class CommanderDamageSheet extends ConsumerWidget {
  const CommanderDamageSheet({super.key, required this.targetProfileId});

  final String targetProfileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(activeGameProvider);
    if (game == null) return const SizedBox.shrink();

    final target = game.seats
        .where((s) => s.profileId == targetProfileId)
        .firstOrNull;
    if (target == null) return const SizedBox.shrink();

    // Every commander belonging to somebody else. A player's own commander
    // cannot deal them commander damage.
    final sources = <({Seat owner, MagicCard card})>[
      for (final seat in game.seats)
        if (seat.profileId != targetProfileId)
          for (final card in seat.damageSources) (owner: seat, card: card),
    ];

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                'Commander damage to ${target.name}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text('${target.life} life'),
            ),
            const Divider(height: 1),
            if (sources.isEmpty)
              const Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  'There is nobody else at the table to deal it.',
                  textAlign: TextAlign.center,
                ),
              )
            else
              for (final source in sources)
                _DamageRow(
                  ownerName: source.owner.name,
                  ownerColorIndex: source.owner.colorIndex,
                  card: source.card,
                  damage: game.damageFrom(source.card.id, targetProfileId),
                  onAdjust: (delta) => ref
                      .read(activeGameProvider.notifier)
                      .adjustCommanderDamage(
                        sourceCardId: source.card.id,
                        targetProfileId: targetProfileId,
                        delta: delta,
                      ),
                ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _DamageRow extends StatelessWidget {
  const _DamageRow({
    required this.ownerName,
    required this.ownerColorIndex,
    required this.card,
    required this.damage,
    required this.onAdjust,
  });

  final String ownerName;
  final int ownerColorIndex;
  final MagicCard card;
  final int damage;
  final void Function(int delta) onAdjust;

  @override
  Widget build(BuildContext context) {
    final lethal = damage >= commanderDamageThreshold;
    final close = damage >= commanderDamageThreshold - 5 && !lethal;
    final color =
        PodWiseColors.seats[ownerColorIndex % PodWiseColors.seats.length];

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: lethal
            ? PodWiseColors.danger.withValues(alpha: 0.18)
            : PodWiseColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: lethal
            ? Border.all(color: PodWiseColors.danger, width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(ownerName, style: TextStyle(fontSize: 11, color: color)),
              ],
            ),
          ),
          _StepButton(
            icon: Icons.remove_rounded,
            onTap: damage > 0 ? () => onAdjust(-1) : null,
          ),
          // The "/21" is always visible: the threshold is the whole point.
          SizedBox(
            width: 74,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$damage',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: lethal
                        ? PodWiseColors.danger
                        : close
                        ? PodWiseColors.caution
                        : Colors.white,
                  ),
                ),
                Text(
                  '/$commanderDamageThreshold',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
          _StepButton(icon: Icons.add_rounded, onTap: () => onAdjust(1)),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;

  /// Null disables the button — used to stop damage going below zero.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(
            icon,
            size: 22,
            color: Colors.white.withValues(alpha: onTap == null ? 0.15 : 0.7),
          ),
        ),
      ),
    );
  }
}

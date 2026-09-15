import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../domain/counters.dart';
import '../../state/providers.dart';

/// Counters and status effects for one player.
///
/// Counters already in play are listed first with steppers; everything else is
/// available from a chip row, so a game with three counters stays uncluttered.
class CountersSheet extends ConsumerWidget {
  const CountersSheet({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(activeGameProvider);
    final seat = game?.seats.where((s) => s.profileId == profileId).firstOrNull;
    if (seat == null) return const SizedBox.shrink();

    final notifier = ref.read(activeGameProvider.notifier);

    // Anything with a value, plus any custom counter the user created.
    final active = seat.counters.entries.where((e) => e.value > 0).toList();
    final activeIds = active.map((e) => e.key).toSet();

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                '${seat.name} — counters & status',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Divider(height: 1),

            const _Label('STATUS'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final status in StatusPresets.all)
                    _StatusChip(
                      status: status,
                      active: seat.statuses.contains(status.id),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        notifier.toggleStatus(profileId, status);
                      },
                    ),
                ],
              ),
            ),

            if (active.isNotEmpty) ...[
              const _Label('IN PLAY'),
              for (final entry in active)
                _CounterRow(
                  type:
                      CounterPresets.byId(entry.key) ??
                      CounterPresets.custom(_labelFromId(entry.key)),
                  value: entry.value,
                  onAdjust: (d) =>
                      notifier.adjustCounter(profileId, entry.key, d),
                  onRemove: () => notifier.removeCounter(profileId, entry.key),
                ),
            ],

            const _Label('ADD A COUNTER'),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final type in CounterPresets.all)
                    if (!activeIds.contains(type.id))
                      ActionChip(
                        avatar: Icon(type.icon, size: 16, color: type.color),
                        label: Text(
                          type.label,
                          style: const TextStyle(fontSize: 12),
                        ),
                        backgroundColor: PodWiseColors.surfaceHigh,
                        side: BorderSide.none,
                        onPressed: () => notifier.adjustCounter(
                          profileId,
                          type.id,
                          type.step,
                        ),
                      ),
                  ActionChip(
                    avatar: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Custom', style: TextStyle(fontSize: 12)),
                    backgroundColor: PodWiseColors.accent.withValues(
                      alpha: 0.2,
                    ),
                    side: BorderSide.none,
                    onPressed: () async {
                      final name = await showDialog<String>(
                        context: context,
                        builder: (_) => const _CustomCounterDialog(),
                      );
                      if (name == null || name.trim().isEmpty) return;
                      notifier.adjustCounter(
                        profileId,
                        CounterPresets.custom(name).id,
                        1,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Recovers a display label from a `custom:spore` style id.
  static String _labelFromId(String id) {
    if (!id.startsWith('custom:')) return id;
    final raw = id.substring(7);
    return raw.isEmpty ? 'Counter' : raw[0].toUpperCase() + raw.substring(1);
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
        color: Colors.white.withValues(alpha: 0.45),
      ),
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.status,
    required this.active,
    required this.onTap,
  });

  final StatusEffect status;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(
        status.icon,
        size: 16,
        color: active ? Colors.black : status.color,
      ),
      label: Text(
        status.label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: active ? FontWeight.w700 : FontWeight.w400,
          color: active ? Colors.black : Colors.white70,
        ),
      ),
      backgroundColor: active ? status.color : PodWiseColors.surfaceHigh,
      side: BorderSide.none,
      onPressed: onTap,
    );
  }
}

class _CounterRow extends StatelessWidget {
  const _CounterRow({
    required this.type,
    required this.value,
    required this.onAdjust,
    required this.onRemove,
  });

  final CounterType type;
  final int value;
  final void Function(int delta) onAdjust;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final lethal = type.isLethal(value);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
          Icon(type.icon, size: 20, color: type.color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (type.lethalAt != null)
                  Text(
                    'Lethal at ${type.lethalAt}',
                    style: TextStyle(
                      fontSize: 10,
                      color: lethal
                          ? PodWiseColors.danger
                          : Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: value > 0 ? () => onAdjust(-type.step) : null,
            icon: const Icon(Icons.remove_rounded),
          ),
          SizedBox(
            width: 44,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: lethal ? PodWiseColors.danger : Colors.white,
              ),
            ),
          ),
          IconButton(
            onPressed: () => onAdjust(type.step),
            icon: const Icon(Icons.add_rounded),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded, size: 18),
            color: Colors.white24,
          ),
        ],
      ),
    );
  }
}

class _CustomCounterDialog extends StatefulWidget {
  const _CustomCounterDialog();

  @override
  State<_CustomCounterDialog> createState() => _CustomCounterDialogState();
}

class _CustomCounterDialogState extends State<_CustomCounterDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: PodWiseColors.surfaceRaised,
      scrollable: true,
      title: const Text('New counter'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(hintText: 'e.g. Treasure, Spore'),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('ADD'),
        ),
      ],
    );
  }
}

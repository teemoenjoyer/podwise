import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../domain/pod.dart';
import '../../state/pod_providers.dart';

/// Editor for one deck.
///
/// This is what makes the Pod Builder work. Scryfall knows the commander; only
/// the group knows whether the deck behind it is a precon or a tuned list, so
/// somebody has to say.
class DeckProfileSheet extends ConsumerStatefulWidget {
  const DeckProfileSheet({super.key, required this.profile});

  final DeckProfile profile;

  @override
  ConsumerState<DeckProfileSheet> createState() => _DeckProfileSheetState();
}

class _DeckProfileSheetState extends ConsumerState<DeckProfileSheet> {
  late int _power = widget.profile.power;
  late final Set<DeckArchetype> _archetypes = {...widget.profile.archetypes};
  late final Set<InteractionType> _interaction = {
    ...widget.profile.interaction,
  };
  late final _name = TextEditingController(text: widget.profile.deckName);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref
        .read(deckEditorProvider)
        .save(
          widget.profile.copyWith(
            deckName: _name.text.trim(),
            power: _power,
            archetypes: _archetypes,
            interaction: _interaction,
          ),
        );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: PodWiseColors.surfaceRaised,
        title: const Text('Delete deck?'),
        content: Text(
          'Removes ${widget.profile.displayName} from '
          '${widget.profile.playerName}. Games already played with it stay in '
          'history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: PodWiseColors.danger,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await ref.read(deckEditorProvider).delete(widget.profile.deckId);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  p.displayName,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  p.commanderName.isEmpty
                      ? '${p.playerName}  ·  no commander recorded'
                      : '${p.playerName}  ·  ${p.commanderName}',
                ),
                trailing: p.isSaved
                    ? IconButton(
                        tooltip: 'Delete deck',
                        icon: const Icon(Icons.delete_outline_rounded),
                        color: PodWiseColors.danger,
                        onPressed: _delete,
                      )
                    : null,
              ),
              const Divider(),

              const _Label('NICKNAME'),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  // Most decks go by their commander, so this is genuinely
                  // optional — it earns its place when someone owns two decks
                  // led by the same card.
                  hintText: p.commanderName.isEmpty
                      ? 'Optional'
                      : 'Optional — defaults to ${p.commanderName}',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              ),

              const _Label('DECK POWER'),
              _PowerSlider(
                value: _power,
                onChanged: (v) => setState(() => _power = v),
              ),
              // Recorded results nudge the rating over time, so it is worth
              // showing what the app currently thinks.
              if (p.gamesPlayed >= 4)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'Adjusted to ${p.effectivePower.toStringAsFixed(1)} from '
                    '${p.gamesPlayed} games at ${(p.winRate * 100).round()}% '
                    'wins.',
                    style: TextStyle(
                      fontSize: 11,
                      color: PodWiseColors.accent.withValues(alpha: 0.85),
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'After four games with this deck the rating starts '
                    'correcting itself from results.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ),

              const _Label('WHAT DOES IT DO?'),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final a in DeckArchetype.values)
                    _Toggle(
                      label: a.label,
                      selected: _archetypes.contains(a),
                      onTap: () => setState(
                        () => _archetypes.contains(a)
                            ? _archetypes.remove(a)
                            : _archetypes.add(a),
                      ),
                    ),
                ],
              ),

              const _Label('WHAT CAN IT ANSWER?'),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final i in InteractionType.values)
                    _Toggle(
                      label: i.label,
                      selected: _interaction.contains(i),
                      onTap: () => setState(
                        () => _interaction.contains(i)
                            ? _interaction.remove(i)
                            : _interaction.add(i),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _save,
                  child: const Text('SAVE'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 20, 0, 10),
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

/// 1–10 with plain-language anchors, because "7" means nothing on its own.
class _PowerSlider extends StatelessWidget {
  const _PowerSlider({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  static String _describe(int power) => switch (power) {
    <= 2 => 'Unmodified precon',
    <= 4 => 'Upgraded precon',
    <= 6 => 'Tuned casual',
    <= 8 => 'High power',
    _ => 'cEDH',
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '$value',
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 12),
            Text(
              _describe(value),
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: 1,
          max: 10,
          divisions: 9,
          activeColor: PodWiseColors.accent,
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ActionChip(
    label: Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
        color: selected ? Colors.black : Colors.white70,
      ),
    ),
    backgroundColor: selected
        ? PodWiseColors.accent
        : PodWiseColors.surfaceHigh,
    side: BorderSide.none,
    onPressed: onTap,
  );
}

import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Commander starts at 40, and in practice almost always does.
const commanderStartingLife = 40;

/// The other totals worth one tap. Brawl and two-player variants differ, and
/// the brief is explicit that the app must not lock anyone to 40.
const startingLifePresets = [20, 25, 30, 40, 50, 60];

/// Shows the starting life as a decision already made, and opens a picker only
/// if someone disagrees.
///
/// This used to be a row of six equally-weighted chips plus CUSTOM, which made
/// choosing look mandatory. It is not: the answer is 40 for all but a handful
/// of games, so 40 is stated and everything else is one tap behind it.
class StartingLifeField extends StatelessWidget {
  const StartingLifeField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  bool get _isDefault => value == commanderStartingLife;

  @override
  Widget build(BuildContext context) {
    // Anything other than 40 is worth flagging, because starting a Commander
    // game on 20 by accident is a miserable way to find out.
    final colour = _isDefault ? Colors.white : PodWiseColors.caution;

    return Material(
      color: PodWiseColors.surfaceRaised,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _pick(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
          child: Row(
            children: [
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  color: colour,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  _isDefault
                      ? 'Commander standard'
                      : 'Changed from $commanderStartingLife',
                  style: TextStyle(
                    fontSize: 12,
                    color: _isDefault
                        ? Colors.white.withValues(alpha: 0.45)
                        : PodWiseColors.caution.withValues(alpha: 0.9),
                  ),
                ),
              ),
              Text(
                'CHANGE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  color: PodWiseColors.accent,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: PodWiseColors.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pick(BuildContext context) async {
    final chosen = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: PodWiseColors.surfaceRaised,
      showDragHandle: true,
      builder: (_) => _LifePickerSheet(value: value),
    );
    // Zero is the sheet's signal for "let me type one", which keeps the sheet
    // itself free of any dependency on the dialog.
    if (chosen == null) return;
    if (chosen > 0) {
      onChanged(chosen);
      return;
    }
    if (!context.mounted) return;

    final custom = await showDialog<int>(
      context: context,
      builder: (_) => _CustomLifeDialog(initial: value),
    );
    if (custom != null) onChanged(custom);
  }
}

class _LifePickerSheet extends StatelessWidget {
  const _LifePickerSheet({required this.value});

  final int value;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ListTile(
            title: Text(
              'Starting life',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
          // Numeric order rather than most-likely-first, because that is how
          // people scan a list of numbers. 40 is marked instead of moved.
          for (final preset in startingLifePresets)
            ListTile(
              leading: Icon(
                preset == value
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: preset == value
                    ? PodWiseColors.accent
                    : Colors.white.withValues(alpha: 0.35),
              ),
              title: Text(
                '$preset',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: preset == commanderStartingLife
                  ? const Text('Commander', style: TextStyle(fontSize: 12))
                  : null,
              onTap: () => Navigator.of(context).pop(preset),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.edit_rounded),
            title: const Text('Something else'),
            subtitle: startingLifePresets.contains(value)
                ? null
                : Text(
                    'Currently $value',
                    style: const TextStyle(fontSize: 12),
                  ),
            onTap: () => Navigator.of(context).pop(0),
          ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}

class _CustomLifeDialog extends StatefulWidget {
  const _CustomLifeDialog({required this.initial});
  final int initial;

  @override
  State<_CustomLifeDialog> createState() => _CustomLifeDialogState();
}

class _CustomLifeDialogState extends State<_CustomLifeDialog> {
  late final _controller =
      TextEditingController(text: widget.initial.toString())
        ..selection = TextSelection(
          baseOffset: 0,
          extentOffset: widget.initial.toString().length,
        );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final parsed = int.tryParse(_controller.text.trim());
    if (parsed != null && parsed > 0) Navigator.of(context).pop(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: PodWiseColors.surfaceRaised,
      title: const Text('Starting life'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        FilledButton(onPressed: _submit, child: const Text('SET')),
      ],
    );
  }
}

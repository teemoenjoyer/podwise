import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../domain/models.dart';
import '../../state/providers.dart';

/// Dialogs for adding, renaming and removing a player.
///
/// Shared by the Players screen and the new-game flow so there is one dialog
/// and one place that decides a new player's seat colour, rather than two
/// copies that can drift apart.
///
/// Returns the saved profile, or null if the dialog was dismissed or the name
/// was blank.
Future<PlayerProfile?> showAddPlayerDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final name = await showDialog<String>(
    context: context,
    builder: (_) => const _AddPlayerDialog(),
  );
  if (name == null || name.trim().isEmpty) return null;

  final existing = ref.read(playerProfilesProvider).valueOrNull ?? const [];
  return ref
      .read(playerProfilesProvider.notifier)
      // Colours cycle through the seat palette, so a new playgroup ends up
      // with a distinguishable colour each without anyone choosing one.
      .add(name, existing.length % PodWiseColors.seats.length);
}

/// Asks for a new name and applies it.
///
/// Returns true if the player was renamed.
Future<bool> showRenamePlayerDialog(
  BuildContext context,
  WidgetRef ref,
  PlayerProfile profile,
) async {
  final name = await showDialog<String>(
    context: context,
    builder: (_) => _NameDialog(
      title: 'Rename player',
      action: 'RENAME',
      initial: profile.name,
    ),
  );
  final trimmed = name?.trim() ?? '';
  if (trimmed.isEmpty || trimmed == profile.name) return false;

  await ref.read(playerProfilesProvider.notifier).rename(profile, trimmed);
  return true;
}

/// Confirms and then removes a player.
///
/// Returns true if they were removed, so the caller can leave a screen that
/// is now about nobody.
Future<bool> showRemovePlayerDialog(
  BuildContext context,
  WidgetRef ref,
  PlayerProfile profile, {
  int deckCount = 0,
}) async {
  // Removing somebody mid-game would leave a seat on the board belonging to a
  // player who no longer exists.
  final active = ref.read(activeGameProvider);
  if (active != null &&
      !active.isFinished &&
      active.seats.any((s) => s.profileId == profile.id)) {
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: PodWiseColors.surfaceRaised,
        title: const Text('They are in the game in progress'),
        content: Text(
          '${profile.name} is playing right now. Finish or abandon that game '
          'before removing them.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return false;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: PodWiseColors.surfaceRaised,
      title: Text('Remove ${profile.name}?'),
      content: Text(
        deckCount == 0
            ? 'Games they have already played stay in history, and still '
                  'count towards every other record they touched.'
            : 'This also removes their '
                  '$deckCount deck${deckCount == 1 ? '' : 's'} and the power '
                  'ratings on them. Games they have already played stay in '
                  'history, and still count towards every other record they '
                  'touched.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: PodWiseColors.danger),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('REMOVE'),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;

  await ref.read(playerProfilesProvider.notifier).remove(profile);
  return true;
}

class _AddPlayerDialog extends StatefulWidget {
  const _AddPlayerDialog();

  @override
  State<_AddPlayerDialog> createState() => _AddPlayerDialogState();
}

class _AddPlayerDialogState extends State<_AddPlayerDialog> {
  @override
  Widget build(BuildContext context) =>
      const _NameDialog(title: 'Add player', action: 'ADD');
}

/// Asks for a name. Pops the text, or null when dismissed.
class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.title,
    required this.action,
    this.initial = '',
  });

  final String title;
  final String action;
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _controller = TextEditingController(text: widget.initial)
    ..selection = TextSelection(
      // Pre-selected, so a rename can be typed straight over.
      baseOffset: 0,
      extentOffset: widget.initial.length,
    );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: PodWiseColors.surfaceRaised,
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(hintText: 'Name'),
        onSubmitted: (v) => Navigator.of(context).pop(v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('CANCEL'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: Text(widget.action),
        ),
      ],
    );
  }
}

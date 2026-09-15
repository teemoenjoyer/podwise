import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/feedback.dart';
import '../../core/theme.dart';
import '../../core/themes.dart';
import '../../state/providers.dart';
import '../../state/settings_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: switch (settings) {
        AsyncData(value: final s) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const _Label('THEME'),
            const SizedBox(height: 10),
            for (final theme in PodWiseTheme.values)
              _ThemeTile(
                theme: theme,
                selected: s.theme == theme,
                onTap: () => notifier.setTheme(theme),
              ),

            const _Label('DURING A GAME'),
            _SwitchTile(
              title: 'Haptics',
              subtitle:
                  'A small buzz confirms a tap landed, which matters on a '
                  'phone lying flat that nobody is looking at directly.',
              value: s.haptics,
              onChanged: (v) async {
                await notifier.setHaptics(v);
                // Demonstrate what was just switched on.
                if (v) {
                  await FeedbackService(
                    haptics: true,
                    sounds: false,
                  ).fire(FeedbackEvent.bigSwing);
                }
              },
            ),
            _SwitchTile(
              title: 'Sounds',
              subtitle:
                  'Uses the phone’s own UI sounds. Off by default — a beep '
                  'per life point gets old fast at a table.',
              value: s.sounds,
              onChanged: notifier.setSounds,
            ),
            _SwitchTile(
              title: 'Keep the screen awake',
              subtitle:
                  'Stops the phone sleeping mid-game. Worth leaving on unless '
                  'you are short of battery.',
              value: s.keepScreenAwake,
              onChanged: notifier.setKeepScreenAwake,
            ),
            _SwitchTile(
              title: 'Show the game clock',
              subtitle:
                  'It always runs from the start of a game. This puts it on '
                  'the board, where you can tap to pause or hold to reset.',
              value: s.showTimer,
              onChanged: notifier.setShowTimer,
            ),

            const _Label('COMMANDER SEARCH'),
            _SwitchTile(
              title: 'Legal commanders only',
              subtitle:
                  'Hides silver-bordered Secret Lairs and anything else not '
                  'legal in sanctioned Commander. Off by default, since most '
                  'groups decide this at the table.',
              value: s.legalCommandersOnly,
              onChanged: notifier.setLegalCommandersOnly,
            ),

            const _Label('STORAGE'),
            const _CachedCardsTile(),

            const SizedBox(height: 28),
            Text(
              'Card data and images from Scryfall. PodWise is an unofficial '
              'fan project and is not affiliated with, endorsed or sponsored '
              'by Wizards of the Coast.',
              style: TextStyle(
                fontSize: 11,
                height: 1.5,
                color: Colors.white.withValues(alpha: 0.35),
              ),
            ),
          ],
        ),
        AsyncError(:final error) => Center(child: Text('$error')),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 26, 0, 6),
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

class _ThemeTile extends StatelessWidget {
  const _ThemeTile({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final PodWiseTheme theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = PodWisePalette.of(theme);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? palette.accent.withValues(alpha: 0.16)
            : PodWiseColors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // A live swatch of the theme, so the choice is made by eye.
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: palette.outline),
                  ),
                  child: Center(
                    child: Wrap(
                      spacing: 3,
                      runSpacing: 3,
                      alignment: WrapAlignment.center,
                      children: [
                        for (final c in [
                          palette.accent,
                          ...palette.seats.take(3),
                        ])
                          Container(
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        theme.label,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        theme.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle_rounded, color: palette.accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(title, style: const TextStyle(fontSize: 16)),
    subtitle: Text(
      subtitle,
      style: TextStyle(
        fontSize: 12,
        height: 1.4,
        color: Colors.white.withValues(alpha: 0.5),
      ),
    ),
    value: value,
    activeThumbColor: PodWiseColors.accent,
    onChanged: onChanged,
  );
}

/// Shows how much card data is cached, and offers to clear it.
class _CachedCardsTile extends ConsumerWidget {
  const _CachedCardsTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(cachedCardCountProvider);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.sd_storage_outlined),
      title: const Text('Cached commanders'),
      subtitle: Text(
        switch (count) {
          AsyncData(:final value) when value > 0 =>
            '$value cards saved for offline search',
          AsyncData() => 'Nothing cached yet',
          _ => 'Checking…',
        },
        style: TextStyle(
          fontSize: 12,
          color: Colors.white.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

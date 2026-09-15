import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/feedback.dart';
import '../core/themes.dart';
import 'providers.dart';

/// Everything the app remembers between sessions that isn't game data.
@immutable
class AppSettings {
  const AppSettings({
    this.theme = PodWiseTheme.darkFantasy,
    this.haptics = true,
    this.sounds = false,
    this.keepScreenAwake = true,
    this.showTimer = false,
    this.legalCommandersOnly = false,
  });

  final PodWiseTheme theme;

  /// On by default: a life counter benefits from confirming a tap landed,
  /// especially on a phone lying flat where you aren't looking at your finger.
  final bool haptics;

  /// Off by default. A beep every time someone loses a life point is
  /// intolerable at a table, so this is opt-in rather than opt-out.
  final bool sounds;

  final bool keepScreenAwake;

  /// Off by default. The clock runs regardless — this only decides whether it
  /// sits on the board, where it competes with the life totals for a glance.
  final bool showTimer;

  /// Hides cards Scryfall marks as not commander-legal.
  ///
  /// Off by default: Commander is a Rule 0 format and silver-bordered Secret
  /// Lairs get played all the time. Groups that stick to sanctioned cards can
  /// turn this on.
  final bool legalCommandersOnly;

  AppSettings copyWith({
    PodWiseTheme? theme,
    bool? haptics,
    bool? sounds,
    bool? keepScreenAwake,
    bool? showTimer,
    bool? legalCommandersOnly,
  }) => AppSettings(
    theme: theme ?? this.theme,
    haptics: haptics ?? this.haptics,
    sounds: sounds ?? this.sounds,
    keepScreenAwake: keepScreenAwake ?? this.keepScreenAwake,
    showTimer: showTimer ?? this.showTimer,
    legalCommandersOnly: legalCommandersOnly ?? this.legalCommandersOnly,
  );

  static const _themeKey = 'theme';
  static const _hapticsKey = 'haptics';
  static const _soundsKey = 'sounds';
  static const _wakeKey = 'keepScreenAwake';
  static const timerKey = 'showTimer';
  static const _legalOnlyKey = 'legalCommandersOnly';

  factory AppSettings.fromMap(Map<String, String> map) {
    bool flag(String key, bool fallback) => switch (map[key]) {
      'true' => true,
      'false' => false,
      _ => fallback,
    };

    return AppSettings(
      theme: PodWiseTheme.fromId(map[_themeKey]),
      haptics: flag(_hapticsKey, true),
      sounds: flag(_soundsKey, false),
      keepScreenAwake: flag(_wakeKey, true),
      showTimer: flag(timerKey, false),
      legalCommandersOnly: flag(_legalOnlyKey, false),
    );
  }

  Map<String, String> toMap() => {
    _themeKey: theme.name,
    _hapticsKey: '$haptics',
    _soundsKey: '$sounds',
    _wakeKey: '$keepScreenAwake',
    timerKey: '$showTimer',
    _legalOnlyKey: '$legalCommandersOnly',
  };
}

/// Marks that the game-clock default has been moved across. Changing a default
/// only affects fresh installs, and every existing one has `showTimer: true`
/// written from when the clock was shown by default.
const _clockDefaultMoved = 'clockDefaultMoved';

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final db = ref.watch(databaseProvider);
    final rows = await db.allSettings();
    final settings = AppSettings.fromMap(rows);

    // The clock used to sit on the board by default and had to be started by
    // hand. It now runs on its own and stays off the board, so installs made
    // before that are moved over once.
    //
    // This does overwrite a deliberate "on" — the stored value cannot tell the
    // two apart — but it only ever happens once, and Settings puts it back.
    if (rows[_clockDefaultMoved] == null) {
      await db.putSetting(_clockDefaultMoved, 'yes');
      if (settings.showTimer) {
        final moved = settings.copyWith(showTimer: false);
        await db.putSetting(AppSettings.timerKey, 'false');
        return moved;
      }
    }

    return settings;
  }

  Future<void> _save(AppSettings next) async {
    // Update state first so the UI responds to the tap immediately; the write
    // is small but should not gate the toggle animating.
    state = AsyncData(next);
    final db = ref.read(databaseProvider);
    for (final entry in next.toMap().entries) {
      await db.putSetting(entry.key, entry.value);
    }
  }

  AppSettings get _current => state.valueOrNull ?? const AppSettings();

  Future<void> setTheme(PodWiseTheme theme) =>
      _save(_current.copyWith(theme: theme));

  Future<void> setHaptics(bool on) => _save(_current.copyWith(haptics: on));

  Future<void> setSounds(bool on) => _save(_current.copyWith(sounds: on));

  Future<void> setKeepScreenAwake(bool on) =>
      _save(_current.copyWith(keepScreenAwake: on));

  Future<void> setShowTimer(bool on) => _save(_current.copyWith(showTimer: on));

  Future<void> setLegalCommandersOnly(bool on) =>
      _save(_current.copyWith(legalCommandersOnly: on));
}

/// Haptics and sounds, configured from the current settings.
///
/// Widgets fire events through this rather than calling HapticFeedback
/// directly, so the settings toggles genuinely take effect everywhere.
final feedbackProvider = Provider<FeedbackService>((ref) {
  final settings =
      ref.watch(settingsProvider).valueOrNull ?? const AppSettings();
  return FeedbackService(haptics: settings.haptics, sounds: settings.sounds);
});

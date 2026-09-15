import 'package:flutter/services.dart';

/// What just happened, so feedback can match its weight to the event.
enum FeedbackEvent {
  /// A single point of life. The most common event by far, so the lightest.
  lifeTick,

  /// A ten-point swing, or a burst committing.
  bigSwing,

  /// Commander damage landed.
  commanderDamage,

  /// A player was knocked out.
  elimination,

  /// Somebody won.
  victory,

  /// A button that changes what's on screen.
  selection,
}

/// Haptics and sounds, both optional per the brief.
///
/// Sound uses the platform's own UI sounds rather than bundled audio: shipping
/// custom clips would mean sourcing and licensing them, and a system click is
/// what a player expects from a counter anyway. This is a deliberate
/// limitation, not an oversight — richer audio would need real assets.
class FeedbackService {
  const FeedbackService({required this.haptics, required this.sounds});

  final bool haptics;
  final bool sounds;

  Future<void> fire(FeedbackEvent event) async {
    if (haptics) await _haptic(event);
    if (sounds) await _sound(event);
  }

  Future<void> _haptic(FeedbackEvent event) async {
    try {
      switch (event) {
        case FeedbackEvent.lifeTick:
        case FeedbackEvent.selection:
          await HapticFeedback.selectionClick();
        case FeedbackEvent.bigSwing:
        case FeedbackEvent.commanderDamage:
          await HapticFeedback.mediumImpact();
        case FeedbackEvent.elimination:
          await HapticFeedback.heavyImpact();
        case FeedbackEvent.victory:
          // Three beats, so winning feels different from being knocked out.
          await HapticFeedback.heavyImpact();
          await Future<void>.delayed(const Duration(milliseconds: 90));
          await HapticFeedback.mediumImpact();
          await Future<void>.delayed(const Duration(milliseconds: 90));
          await HapticFeedback.heavyImpact();
      }
    } catch (_) {
      // Some devices and power modes refuse haptics. Never worth failing over.
    }
  }

  Future<void> _sound(FeedbackEvent event) async {
    try {
      await SystemSound.play(switch (event) {
        FeedbackEvent.elimination ||
        FeedbackEvent.victory => SystemSoundType.alert,
        _ => SystemSoundType.click,
      });
    } catch (_) {
      // Best effort only.
    }
  }
}

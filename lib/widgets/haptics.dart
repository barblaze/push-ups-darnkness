import 'package:flutter/services.dart';

/// Hápticos centralizados que respetan la preferencia del usuario.
class Haptics {
  Haptics._();

  /// Se actualiza desde [GameState.hapticsEnabled].
  static bool enabled = true;

  static void click() => _run(HapticFeedback.lightImpact);

  static void rep() => _run(HapticFeedback.mediumImpact);

  static void milestone() => _run(HapticFeedback.heavyImpact);

  static void celebrate() => _run(HapticFeedback.vibrate);

  static void _run(Future<void> Function() feedback) {
    if (!enabled) return;
    feedback();
  }
}

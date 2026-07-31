import 'dart:math' as math;

import 'quality.dart';

class RepScoring {
  static int points({required Quality quality, required int combo}) {
    final depth = quality.depthRatio.clamp(0.0, 1.0);
    final straight = quality.straightness.clamp(0.0, 1.0);
    final base = 10 * (0.5 + 0.5 * depth) * (0.6 + 0.4 * straight);
    final multiplier = 1.0 + 0.1 * math.min(combo - 1, 10);
    return (base * multiplier).round();
  }

  static int missionBonus(int targetReps, int completedReps) {
    if (completedReps >= targetReps) return 50;
    return 0;
  }
}

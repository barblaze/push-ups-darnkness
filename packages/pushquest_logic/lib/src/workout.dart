import 'placement.dart';
import 'pushup_mode.dart';

class WorkoutSummary {
  const WorkoutSummary({
    required this.startedAt,
    required this.mode,
    required this.placement,
    required this.reps,
    required this.points,
    required this.bestCombo,
    required this.durationSeconds,
  });

  final DateTime startedAt;
  final PushUpMode mode;
  final CameraPlacement placement;
  final int reps;
  final int points;
  final int bestCombo;
  final int durationSeconds;
}

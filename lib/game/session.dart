import 'package:pushquest_logic/pushquest_logic.dart';

class SessionRecord {
  const SessionRecord({
    required this.startedAt,
    required this.mode,
    required this.reps,
    required this.points,
    required this.bestCombo,
    required this.durationSeconds,
  });

  final DateTime startedAt;
  final PushUpMode mode;
  final int reps;
  final int points;
  final int bestCombo;
  final int durationSeconds;

  Map<String, dynamic> toJson() => {
    'd': startedAt.millisecondsSinceEpoch,
    'm': mode.name,
    'r': reps,
    'p': points,
    'c': bestCombo,
    's': durationSeconds,
  };

  static SessionRecord fromJson(Map<String, dynamic> json) {
    return SessionRecord(
      startedAt: DateTime.fromMillisecondsSinceEpoch(json['d'] as int),
      mode: PushUpMode.values.asNameMap()[json['m']] ?? PushUpMode.floor,
      reps: json['r'] as int,
      points: json['p'] as int,
      bestCombo: json['c'] as int,
      durationSeconds: json['s'] as int,
    );
  }
}

import 'package:pushquest_logic/pushquest_logic.dart';

class SessionRecord {
  const SessionRecord({
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

  Map<String, dynamic> toJson() => {
        'd': startedAt.millisecondsSinceEpoch,
        'm': mode.name,
        'pl': placement.name,
        'r': reps,
        'p': points,
        'c': bestCombo,
        's': durationSeconds,
      };

  static SessionRecord fromJson(Map<String, dynamic> json) {
    return SessionRecord(
      startedAt: DateTime.fromMillisecondsSinceEpoch(json['d'] as int),
      mode: PushUpMode.values.asNameMap()[json['m']] ?? PushUpMode.floor,
      placement: CameraPlacement.values.asNameMap()[json['pl']] ??
          CameraPlacement.profile,
      reps: json['r'] as int,
      points: json['p'] as int,
      bestCombo: json['c'] as int,
      durationSeconds: json['s'] as int,
    );
  }
}

class PersistedData {
  const PersistedData({
    required this.totalReps,
    required this.totalXp,
    required this.bestSessionReps,
    required this.bestCombo,
    required this.streakDays,
    required this.floorReps,
    required this.sessionsCount,
    required this.daysActive,
    required this.lastActiveDate,
    required this.sessions,
    required this.defaultMode,
    required this.defaultPlacement,
    this.parallelReps = 0,
    this.arcadeBest = 0,
    this.hasSeenOnboarding = false,
    this.hapticsEnabled = true,
  });

  final int totalReps;
  final int totalXp;
  final int bestSessionReps;
  final int bestCombo;
  final int streakDays;
  final int floorReps;
  final int parallelReps;
  final int arcadeBest;
  final int sessionsCount;
  final int daysActive;
  final String? lastActiveDate;
  final List<SessionRecord> sessions;
  final PushUpMode defaultMode;
  final CameraPlacement defaultPlacement;
  final bool hasSeenOnboarding;
  final bool hapticsEnabled;

  static const PersistedData empty = PersistedData(
    totalReps: 0,
    totalXp: 0,
    bestSessionReps: 0,
    bestCombo: 0,
    streakDays: 0,
    floorReps: 0,
    sessionsCount: 0,
    daysActive: 0,
    lastActiveDate: null,
    sessions: [],
    defaultMode: PushUpMode.floor,
    defaultPlacement: CameraPlacement.front,
  );

  PlayerStats get stats => PlayerStats(
        totalReps: totalReps,
        totalXp: totalXp,
        bestSessionReps: bestSessionReps,
        bestCombo: bestCombo,
        streakDays: streakDays,
        floorReps: floorReps,
        parallelReps: parallelReps,
        arcadeBest: arcadeBest,
        sessionsCount: sessionsCount,
        daysActive: daysActive,
      );

  Map<String, dynamic> toJson() => {
        'totalReps': totalReps,
        'totalXp': totalXp,
        'bestSessionReps': bestSessionReps,
        'bestCombo': bestCombo,
        'streakDays': streakDays,
        'floorReps': floorReps,
        'parallelReps': parallelReps,
        'arcadeBest': arcadeBest,
        'sessionsCount': sessionsCount,
        'daysActive': daysActive,
        'lastActiveDate': lastActiveDate,
        'sessions': sessions.map((s) => s.toJson()).toList(),
        'defaultMode': defaultMode.name,
        'defaultPlacement': defaultPlacement.name,
        'onboarded': hasSeenOnboarding,
        'haptics': hapticsEnabled,
      };

  static PersistedData fromJson(Map<String, dynamic> json) {
    return PersistedData(
      totalReps: json['totalReps'] as int? ?? 0,
      totalXp: json['totalXp'] as int? ?? 0,
      bestSessionReps: json['bestSessionReps'] as int? ?? 0,
      bestCombo: json['bestCombo'] as int? ?? 0,
      streakDays: json['streakDays'] as int? ?? 0,
      floorReps: json['floorReps'] as int? ?? 0,
      parallelReps: json['parallelReps'] as int? ?? 0,
      arcadeBest: json['arcadeBest'] as int? ?? 0,
      sessionsCount: json['sessionsCount'] as int? ?? 0,
      daysActive: json['daysActive'] as int? ?? 0,
      lastActiveDate: json['lastActiveDate'] as String?,
      sessions: (json['sessions'] as List<dynamic>? ?? const [])
          .map((e) => SessionRecord.fromJson(e as Map<String, dynamic>))
          .toList(),
      defaultMode: PushUpMode.values.asNameMap()[json['defaultMode']] ??
          PushUpMode.floor,
      defaultPlacement:
          CameraPlacement.values.asNameMap()[json['defaultPlacement']] ??
              CameraPlacement.front,
      hasSeenOnboarding: json['onboarded'] as bool? ?? false,
      hapticsEnabled: json['haptics'] as bool? ?? true,
    );
  }
}

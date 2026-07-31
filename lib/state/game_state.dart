import 'package:flutter/foundation.dart';
import 'package:pushquest_logic/pushquest_logic.dart';

import '../game/session.dart';
import '../game/storage.dart';

class WorkoutApplyResult {
  const WorkoutApplyResult({
    required this.session,
    required this.missionBonus,
    required this.missionCompleted,
    required this.newlyUnlocked,
    required this.levelBefore,
    required this.levelAfter,
  });

  final SessionRecord session;
  final int missionBonus;
  final bool missionCompleted;
  final List<Achievement> newlyUnlocked;
  final int levelBefore;
  final int levelAfter;

  int get awardedPoints => session.points;
}

class GameState extends ChangeNotifier {
  GameState._(this._storage, this._data);

  final GameStorage _storage;
  PersistedData _data;

  PersistedData get data => _data;

  PlayerStats get stats => _data.stats;

  PushUpMode get defaultMode => _data.defaultMode;

  CameraPlacement get defaultPlacement => _data.defaultPlacement;

  List<SessionRecord> get sessions => _data.sessions;

  int get todayReps {
    final today = _dateKey(DateTime.now());
    return sessions
        .where((s) => _dateKey(s.startedAt) == today)
        .fold(0, (sum, s) => sum + s.reps);
  }

  DailyMission get dailyMission => DailyMission.forDay(DateTime.now());

  List<Achievement> get unlockedAchievements =>
      AchievementCatalog.all.where((a) => a.isUnlocked(stats)).toList();

  LevelInfo get levelInfo => Levels.fromXp(stats.totalXp);

  AvatarStage get avatar => Avatar.forLevel(levelInfo.level);

  static Future<GameState> load({GameStorage? storage}) async {
    final s = storage ?? PrefsGameStorage();
    final data = await s.load();
    return GameState._(s, data);
  }

  Future<void> setDefaultMode(PushUpMode mode) async {
    if (_data.defaultMode == mode) return;
    _data = _copyWith(_data, defaultMode: mode);
    notifyListeners();
    await _persist();
  }

  Future<void> setDefaultPlacement(CameraPlacement placement) async {
    if (_data.defaultPlacement == placement) return;
    _data = _copyWith(_data, defaultPlacement: placement);
    notifyListeners();
    await _persist();
  }

  Future<WorkoutApplyResult> applyWorkout(WorkoutSummary summary) async {
    final today = DateTime.now();
    final mission = DailyMission.forDay(today);
    final beforeReps = todayReps;

    final completedMissionNow = !mission.isComplete(beforeReps) &&
        mission.isComplete(beforeReps + summary.reps);
    final bonus = completedMissionNow
        ? RepScoring.missionBonus(mission.targetReps, beforeReps + summary.reps)
        : 0;

    final awardedPoints = summary.points + bonus;

    final levelBefore = Levels.fromXp(_data.totalXp).level;
    final unlockedBefore = unlockedAchievements.map((a) => a.id).toSet();

    var streak = _data.streakDays;
    var daysActive = _data.daysActive;
    final todayKey = _dateKey(today);
    if (_data.lastActiveDate == null || _data.lastActiveDate != todayKey) {
      if (_data.lastActiveDate ==
          _dateKey(today.subtract(const Duration(days: 1)))) {
        streak += 1;
      } else {
        streak = 1;
      }
      daysActive += 1;
    }

    final session = SessionRecord(
      startedAt: summary.startedAt,
      mode: summary.mode,
      placement: summary.placement,
      reps: summary.reps,
      points: awardedPoints,
      bestCombo: summary.bestCombo,
      durationSeconds: summary.durationSeconds,
    );

    final sessions = [..._data.sessions, session];
    if (sessions.length > 200) {
      sessions.removeRange(0, sessions.length - 200);
    }

    _data = PersistedData(
      totalReps: _data.totalReps + summary.reps,
      totalXp: _data.totalXp + awardedPoints,
      bestSessionReps: _data.bestSessionReps > summary.reps
          ? _data.bestSessionReps
          : summary.reps,
      bestCombo: _data.bestCombo > summary.bestCombo
          ? _data.bestCombo
          : summary.bestCombo,
      streakDays: streak,
      floorReps: _data.floorReps +
          (summary.mode == PushUpMode.floor ? summary.reps : 0),
      sessionsCount: _data.sessionsCount + 1,
      daysActive: daysActive,
      lastActiveDate: todayKey,
      sessions: sessions,
      defaultMode: _data.defaultMode,
      defaultPlacement: _data.defaultPlacement,
    );

    final newlyUnlocked = AchievementCatalog.all
        .where((a) => !unlockedBefore.contains(a.id) && a.isUnlocked(stats))
        .toList();

    notifyListeners();
    await _persist();

    return WorkoutApplyResult(
      session: session,
      missionBonus: bonus,
      missionCompleted: completedMissionNow,
      newlyUnlocked: newlyUnlocked,
      levelBefore: levelBefore,
      levelAfter: Levels.fromXp(_data.totalXp).level,
    );
  }

  Future<void> _persist() => _storage.save(_data);

  static String _dateKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static PersistedData _copyWith(
    PersistedData data, {
    PushUpMode? defaultMode,
    CameraPlacement? defaultPlacement,
  }) {
    return PersistedData(
      totalReps: data.totalReps,
      totalXp: data.totalXp,
      bestSessionReps: data.bestSessionReps,
      bestCombo: data.bestCombo,
      streakDays: data.streakDays,
      floorReps: data.floorReps,
      sessionsCount: data.sessionsCount,
      daysActive: data.daysActive,
      lastActiveDate: data.lastActiveDate,
      sessions: data.sessions,
      defaultMode: defaultMode ?? data.defaultMode,
      defaultPlacement: defaultPlacement ?? data.defaultPlacement,
    );
  }
}

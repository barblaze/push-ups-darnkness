import 'package:flutter_test/flutter_test.dart';
import 'package:pushquest/game/session.dart';
import 'package:pushquest/state/game_state.dart';
import 'package:pushquest_logic/pushquest_logic.dart';

import 'helpers.dart';

void main() {
  group('GameState.applyWorkout', () {
    test(
      'first workout starts streak, count and unlocks first achievement',
      () async {
        final state = await GameState.load(storage: MemoryGameStorage());

        final result = await state.applyWorkout(
          WorkoutSummary(
            startedAt: DateTime(2026, 7, 31),
            mode: PushUpMode.floor,
            placement: CameraPlacement.profile,
            reps: 10,
            points: 80,
            bestCombo: 3,
            durationSeconds: 60,
          ),
        );

        expect(state.stats.sessionsCount, 1);
        expect(state.stats.totalReps, 10);
        expect(state.stats.totalXp, 80);
        expect(state.stats.streakDays, 1);
        expect(state.stats.daysActive, 1);
        expect(state.stats.floorReps, 10);
        expect(state.stats.bestSessionReps, 10);
        expect(state.stats.bestCombo, 3);

        expect(
          result.newlyUnlocked.map((a) => a.id),
          contains('first_workout'),
        );
        expect(state.unlockedAchievements.length, greaterThanOrEqualTo(1));
      },
    );

    test('mission bonus applied once per day', () async {
      final state = await GameState.load(storage: MemoryGameStorage());
      final mission = DailyMission.forDay(DateTime.now());

      final first = await state.applyWorkout(
        WorkoutSummary(
          startedAt: DateTime.now(),
          mode: PushUpMode.floor,
          placement: CameraPlacement.front,
          reps: mission.targetReps,
          points: 100,
          bestCombo: 5,
          durationSeconds: 120,
        ),
      );

      expect(first.missionCompleted, isTrue);
      expect(first.missionBonus, 50);
      expect(first.session.points, 150);
      expect(state.stats.totalXp, 150);

      final second = await state.applyWorkout(
        WorkoutSummary(
          startedAt: DateTime.now(),
          mode: PushUpMode.floor,
          placement: CameraPlacement.profile,
          reps: 5,
          points: 30,
          bestCombo: 2,
          durationSeconds: 30,
        ),
      );

      expect(second.missionCompleted, isFalse);
      expect(second.missionBonus, 0);
      expect(second.session.points, 30);
      expect(state.stats.totalXp, 180);
    });

    test('accumulates stats and level rises with xp', () async {
      final state = await GameState.load(storage: MemoryGameStorage());

      await state.applyWorkout(
        WorkoutSummary(
          startedAt: DateTime(2026, 7, 31),
          mode: PushUpMode.parallettes,
          placement: CameraPlacement.profile,
          reps: 20,
          points: 150,
          bestCombo: 10,
          durationSeconds: 100,
        ),
      );

      expect(state.levelInfo.level, greaterThanOrEqualTo(2));
      expect(state.stats.parallettesReps, 20);
      expect(state.stats.bestCombo, 10);

      final result = await state.applyWorkout(
        WorkoutSummary(
          startedAt: DateTime(2026, 7, 31),
          mode: PushUpMode.floor,
          placement: CameraPlacement.profile,
          reps: 0,
          points: 0,
          bestCombo: 0,
          durationSeconds: 5,
        ),
      );
      expect(result.newlyUnlocked, isEmpty);
    });

    test('default mode can be changed and persists', () async {
      final storage = MemoryGameStorage();
      final state = await GameState.load(storage: storage);

      await state.setDefaultMode(PushUpMode.parallettes);
      expect(state.defaultMode, PushUpMode.parallettes);
      expect(storage.data.defaultMode, PushUpMode.parallettes);
    });

    test('default placement can be changed and persists', () async {
      final storage = MemoryGameStorage();
      final state = await GameState.load(storage: storage);

      expect(state.defaultPlacement, CameraPlacement.profile);
      await state.setDefaultPlacement(CameraPlacement.front);
      expect(state.defaultPlacement, CameraPlacement.front);
      expect(storage.data.defaultPlacement, CameraPlacement.front);
    });
  });

  group('Persistence roundtrip', () {
    test('PersistedData survives json encode/decode', () {
      final original = PersistedData(
        totalReps: 123,
        totalXp: 456,
        bestSessionReps: 40,
        bestCombo: 8,
        streakDays: 3,
        floorReps: 100,
        parallettesReps: 23,
        sessionsCount: 4,
        daysActive: 3,
        lastActiveDate: '2026-07-31',
        sessions: [
          SessionRecord(
            startedAt: DateTime(2026, 7, 31, 10, 30),
            mode: PushUpMode.floor,
            placement: CameraPlacement.profile,
            reps: 25,
            points: 180,
            bestCombo: 6,
            durationSeconds: 300,
          ),
        ],
        defaultMode: PushUpMode.parallettes,
        defaultPlacement: CameraPlacement.front,
      );

      final decoded = PersistedData.fromJson(original.toJson());

      expect(decoded.totalReps, original.totalReps);
      expect(decoded.totalXp, original.totalXp);
      expect(decoded.streakDays, original.streakDays);
      expect(decoded.defaultMode, PushUpMode.parallettes);
      expect(decoded.defaultPlacement, CameraPlacement.front);
      expect(decoded.sessions.length, 1);
      expect(decoded.sessions.first.reps, 25);
      expect(decoded.sessions.first.mode, PushUpMode.floor);
      expect(decoded.sessions.first.placement, CameraPlacement.profile);
    });
  });
}

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
            placement: CameraPlacement.front,
            reps: 10,
            points: 80,
            bestCombo: 3,
            durationSeconds: 60,
          ),
        );

        // El bonus de la misión diaria depende del día en que se ejecuta el
        // test; el resto de estadísticas no.
        final mission = DailyMission.forDay(DateTime.now());
        final missionBonus =
            mission.isComplete(10) ? RepScoring.missionBonus(mission.targetReps, 10) : 0;

        expect(state.stats.sessionsCount, 1);
        expect(state.stats.totalReps, 10);
        expect(state.stats.totalXp, 80 + missionBonus);
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
          placement: CameraPlacement.front,
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
          mode: PushUpMode.floor,
          placement: CameraPlacement.front,
          reps: 20,
          points: 150,
          bestCombo: 10,
          durationSeconds: 100,
        ),
      );

      expect(state.levelInfo.level, greaterThanOrEqualTo(2));
      expect(state.stats.floorReps, 20);
      expect(state.stats.bestCombo, 10);

      final result = await state.applyWorkout(
        WorkoutSummary(
          startedAt: DateTime(2026, 7, 31),
          mode: PushUpMode.floor,
          placement: CameraPlacement.front,
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

      await state.setDefaultMode(PushUpMode.free);
      expect(state.defaultMode, PushUpMode.free);
      expect(storage.data.defaultMode, PushUpMode.free);
    });

    test('default placement stays front', () async {
      final storage = MemoryGameStorage();
      final state = await GameState.load(storage: storage);

      expect(state.defaultPlacement, CameraPlacement.front);
      expect(storage.data.defaultPlacement, CameraPlacement.front);
    });

    test('parallel reps accumulate only in parallel mode', () async {
      final state = await GameState.load(storage: MemoryGameStorage());

      await state.applyWorkout(
        WorkoutSummary(
          startedAt: DateTime(2026, 7, 31),
          mode: PushUpMode.parallel,
          placement: CameraPlacement.front,
          reps: 20,
          points: 100,
          bestCombo: 4,
          durationSeconds: 60,
        ),
      );
      expect(state.stats.parallelReps, 20);
      expect(state.stats.floorReps, 0);
    });

    test('onboarding and haptics flags persist', () async {
      final storage = MemoryGameStorage();
      final state = await GameState.load(storage: storage);

      expect(state.hasSeenOnboarding, isFalse);
      await state.markOnboardingSeen();
      expect(state.hasSeenOnboarding, isTrue);
      expect(storage.data.hasSeenOnboarding, isTrue);

      expect(state.hapticsEnabled, isTrue);
      await state.setHapticsEnabled(false);
      expect(state.hapticsEnabled, isFalse);
      expect(storage.data.hapticsEnabled, isFalse);

      expect(state.arcadeSensitivity, 50);
      await state.setArcadeSensitivity(20);
      expect(state.arcadeSensitivity, 20);
      expect(storage.data.arcadeSensitivity, 20);
    });

    test('arcade session keeps best score and counts reps', () async {
      final state = await GameState.load(storage: MemoryGameStorage());

      await state.applyWorkout(
        WorkoutSummary(
          startedAt: DateTime(2026, 7, 31),
          mode: PushUpMode.arcade,
          placement: CameraPlacement.front,
          reps: 8,
          points: 50,
          bestCombo: 2,
          durationSeconds: 45,
        ),
      );
      expect(state.stats.arcadeBest, 5);
      expect(state.stats.totalReps, 8);

      await state.applyWorkout(
        WorkoutSummary(
          startedAt: DateTime(2026, 7, 31),
          mode: PushUpMode.arcade,
          placement: CameraPlacement.front,
          reps: 4,
          points: 20,
          bestCombo: 1,
          durationSeconds: 30,
        ),
      );
      expect(state.stats.arcadeBest, 5);
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
        sessionsCount: 4,
        daysActive: 3,
        lastActiveDate: '2026-07-31',
        sessions: [
          SessionRecord(
            startedAt: DateTime(2026, 7, 31, 10, 30),
            mode: PushUpMode.floor,
            placement: CameraPlacement.front,
            reps: 25,
            points: 180,
            bestCombo: 6,
            durationSeconds: 300,
          ),
        ],
        defaultMode: PushUpMode.free,
        defaultPlacement: CameraPlacement.front,
        arcadeSensitivity: 25,
      );

      final decoded = PersistedData.fromJson(original.toJson());

      expect(decoded.totalReps, original.totalReps);
      expect(decoded.totalXp, original.totalXp);
      expect(decoded.streakDays, original.streakDays);
      expect(decoded.defaultMode, PushUpMode.free);
      expect(decoded.defaultPlacement, CameraPlacement.front);
      expect(decoded.arcadeSensitivity, 25);
      expect(decoded.sessions.length, 1);
      expect(decoded.sessions.first.reps, 25);
      expect(decoded.sessions.first.mode, PushUpMode.floor);
      expect(decoded.sessions.first.placement, CameraPlacement.front);
    });

    test('legacy profile placement parses as front', () {
      final decoded = SessionRecord.fromJson({
        'd': DateTime(2026, 8, 13).millisecondsSinceEpoch,
        'm': 'floor',
        'pl': 'profile',
        'r': 10,
        'p': 80,
        'c': 2,
        's': 60,
      });
      expect(decoded.placement, CameraPlacement.front);
    });
  });
}

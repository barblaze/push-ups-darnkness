import 'package:pushquest_logic/pushquest_logic.dart';
import 'package:test/test.dart';

void main() {
  group('Levels', () {
    test('starts at level 1', () {
      final info = Levels.fromXp(0);
      expect(info.level, 1);
      expect(info.xpIntoLevel, 0);
      expect(info.progress, 0.0);
    });

    test('levels up at 100 xp', () {
      expect(Levels.fromXp(99).level, 1);
      expect(Levels.fromXp(100).level, 2);
      expect(Levels.fromXp(100).xpIntoLevel, 0);
    });

    test('xp needed grows with level', () {
      expect(Levels.xpForLevel(1), 100);
      expect(Levels.xpForLevel(2), 175);
      expect(Levels.xpForLevel(3), 250);
    });

    test('titles clamp to the last one', () {
      expect(Levels.titleFor(1), 'Novato');
      expect(Levels.titleFor(5), 'Guerrero');
      expect(Levels.titleFor(999), 'Fénix');
    });
  });

  group('Avatar', () {
    test('stage grows with level', () {
      expect(Avatar.forLevel(1).name, 'Huevo');
      expect(Avatar.forLevel(4).name, 'Pollito');
      expect(Avatar.forLevel(13).name, 'Dragón');
      expect(Avatar.forLevel(99).name, 'Dragón');
    });
  });

  group('Achievements', () {
    test('first workout unlocks with one session', () {
      const stats = PlayerStats(sessionsCount: 1);
      expect(
        AchievementCatalog.byId('first_workout').isUnlocked(stats),
        isTrue,
      );
    });

    test('reps achievements threshold', () {
      const stats = PlayerStats(totalReps: 100);
      expect(AchievementCatalog.byId('reps_25').isUnlocked(stats), isTrue);
      expect(AchievementCatalog.byId('reps_50').isUnlocked(stats), isTrue);
      expect(AchievementCatalog.byId('reps_150').isUnlocked(stats), isFalse);
    });

    test('streak achievements threshold', () {
      const stats = PlayerStats(streakDays: 7);
      expect(AchievementCatalog.byId('streak_3').isUnlocked(stats), isTrue);
      expect(AchievementCatalog.byId('streak_7').isUnlocked(stats), isTrue);
      expect(AchievementCatalog.byId('streak_14').isUnlocked(stats), isFalse);
    });

    test('longer streak and combo achievements', () {
      const stats = PlayerStats(streakDays: 30, bestCombo: 30);
      expect(AchievementCatalog.byId('streak_14').isUnlocked(stats), isTrue);
      expect(AchievementCatalog.byId('streak_30').isUnlocked(stats), isTrue);
      expect(AchievementCatalog.byId('combo_15').isUnlocked(stats), isTrue);
      expect(AchievementCatalog.byId('combo_30').isUnlocked(stats), isTrue);
      const stats2 = PlayerStats(streakDays: 14, bestCombo: 12);
      expect(AchievementCatalog.byId('streak_30').isUnlocked(stats2), isFalse);
      expect(AchievementCatalog.byId('combo_30').isUnlocked(stats2), isFalse);
    });

    test('parallel achievements threshold', () {
      const stats = PlayerStats(parallelReps: 100);
      expect(
        AchievementCatalog.byId('parallel_100').isUnlocked(stats),
        isTrue,
      );
      expect(
        AchievementCatalog.byId('parallel_300').isUnlocked(stats),
        isFalse,
      );
    });

    test('arcade achievements threshold', () {
      const stats = PlayerStats(arcadeBest: 15);
      expect(AchievementCatalog.byId('arcade_5').isUnlocked(stats), isTrue);
      expect(AchievementCatalog.byId('arcade_15').isUnlocked(stats), isTrue);
      expect(AchievementCatalog.byId('arcade_30').isUnlocked(stats), isFalse);
    });

    test('level achievements derive from xp', () {
      final stats = PlayerStats(totalXp: 500);
      expect(Levels.fromXp(500).level, 3);
      expect(AchievementCatalog.byId('level_3').isUnlocked(stats), isTrue);
      expect(AchievementCatalog.byId('level_5').isUnlocked(stats), isFalse);
      final stats5 = PlayerStats(totalXp: Levels.totalXpForLevel(5));
      expect(
        AchievementCatalog.byId('level_5').isUnlocked(stats5),
        isTrue,
      );
    });

    test('every achievement has a unique id', () {
      final ids = AchievementCatalog.all.map((a) => a.id).toSet();
      expect(ids.length, AchievementCatalog.all.length);
    });
  });

  group('DailyMission', () {
    test('target is deterministic and bounded', () {
      for (var day = 1; day <= 28; day++) {
        for (var month = 1; month <= 12; month++) {
          final mission = DailyMission.forDay(DateTime(2026, month, day));
          expect(mission.targetReps, inInclusiveRange(6, 24));
        }
      }
    });

    test('completion check', () {
      final mission = DailyMission.forDay(DateTime(2026, 7, 31));
      expect(mission.targetReps, 22);
      expect(mission.isComplete(10), isFalse);
      expect(mission.isComplete(22), isTrue);
      expect(mission.progress(11), closeTo(0.5, 1e-9));
    });
  });

  group('PushUpMode', () {
    test('arcade and free count any rep; floor and parallel do not', () {
      expect(PushUpMode.arcade.countsAnyRep, isTrue);
      expect(PushUpMode.free.countsAnyRep, isTrue);
      expect(PushUpMode.floor.countsAnyRep, isFalse);
      expect(PushUpMode.parallel.countsAnyRep, isFalse);
    });

    test('arcade has its own label and icon', () {
      expect(PushUpMode.arcade.label, 'Arcade');
      expect(PushUpMode.arcade.icon, '🎮');
      expect(PushUpMode.arcade.positionHint, isNotEmpty);
    });
  });

  group('WeeklyGoal', () {
    test('monday is the start of the week', () {
      expect(
        WeeklyGoal.mondayOf(DateTime(2026, 8, 5)).day,
        3,
      );
      expect(
        WeeklyGoal.mondayOf(DateTime(2026, 8, 3)).day,
        3,
      );
      expect(
        WeeklyGoal.mondayOf(DateTime(2026, 8, 9)).day,
        3,
      );
    });

    test('includes only sessions of the same week', () {
      final goal = WeeklyGoal.forDay(DateTime(2026, 8, 5));
      expect(goal.includes(DateTime(2026, 8, 3)), isTrue);
      expect(goal.includes(DateTime(2026, 8, 9)), isTrue);
      expect(goal.includes(DateTime(2026, 8, 2)), isFalse);
      expect(goal.includes(DateTime(2026, 8, 10)), isFalse);
    });

    test('target is deterministic and bounded within a week', () {
      final goal = WeeklyGoal.forDay(DateTime(2026, 8, 5));
      final otherDay = WeeklyGoal.forDay(DateTime(2026, 8, 7));
      expect(goal.targetReps, otherDay.targetReps);
      expect(goal.targetReps, inInclusiveRange(20, 40));
    });

    test('progress clamps', () {
      final goal = WeeklyGoal.forDay(DateTime(2026, 8, 5));
      expect(goal.progress(0), 0.0);
      expect(goal.isComplete(goal.targetReps), isTrue);
      expect(goal.progress(goal.targetReps * 2), 1.0);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:pushquest_logic/pushquest_logic.dart';

import '../state/game_state.dart';
import '../theme/app_theme.dart';

class ChallengesScreen extends StatelessWidget {
  const ChallengesScreen({super.key, required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final mission = state.dailyMission;
        final progress = mission.progress(state.todayReps);
        final done = progress >= 1;
        final unlocked = state.unlockedAchievements;
        return Scaffold(
          appBar: AppBar(title: const Text('Desafíos')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Text('🎯', style: TextStyle(fontSize: 24)),
                            SizedBox(width: 10),
                            Text(
                              'Misión del día',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${mission.targetReps} push-ups',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              '${state.todayReps}/${mission.targetReps}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: done
                                    ? AppColors.success
                                    : AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 10,
                            backgroundColor: AppColors.surfaceAlt,
                            valueColor: AlwaysStoppedAnimation(
                              done ? AppColors.success : AppColors.accent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          done
                              ? '¡Completada! +50 XP ya sumados.'
                              : 'Recompensa: +50 XP al completarla hoy.',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Logros',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      '${unlocked.length}/${AchievementCatalog.all.length}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final achievement in AchievementCatalog.all)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _achievementTile(achievement),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _achievementTile(Achievement achievement) {
    final isUnlocked = achievement.isUnlocked(state.stats);
    return Card(
      child: Opacity(
        opacity: isUnlocked ? 1 : 0.45,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Text(achievement.icon, style: const TextStyle(fontSize: 26)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      achievement.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      achievement.description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isUnlocked ? Icons.check_circle : Icons.lock_outline,
                color: isUnlocked ? AppColors.success : AppColors.textSecondary,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:pushquest_logic/pushquest_logic.dart';

import '../state/game_state.dart';
import '../theme/app_theme.dart';
import 'challenges_screen.dart';
import 'stats_screen.dart';
import 'workout_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final level = state.levelInfo;
        final mission = state.dailyMission;
        final avatar = state.avatar;
        return Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(avatar, level),
                  const SizedBox(height: 20),
                  _xpCard(level),
                  const SizedBox(height: 16),
                  _modeSelector(),
                  const SizedBox(height: 16),
                  _missionCard(mission),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => _startWorkout(context),
                    child: const Text('ENTRENAR'),
                  ),
                  const SizedBox(height: 20),
                  _navRow(context),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _startWorkout(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkoutScreen(state: state, mode: state.defaultMode),
      ),
    );
  }

  Widget _header(AvatarStage avatar, LevelInfo level) {
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Color(avatar.color),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(avatar.emoji, style: const TextStyle(fontSize: 36)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PushQuest',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Nivel ${level.level} · ${avatar.name}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF262E3A)),
          ),
          child: Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text(
                '${state.stats.streakDays}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _xpCard(LevelInfo level) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Nivel ${level.level}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '${level.xpIntoLevel} / ${level.xpForNext} XP',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: level.progress,
                minHeight: 10,
                backgroundColor: AppColors.surfaceAlt,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              Levels.titleFor(level.level),
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modeSelector() {
    return SegmentedButton<PushUpMode>(
      segments: [
        for (final mode in PushUpMode.values)
          ButtonSegment(value: mode, label: Text('${mode.icon} ${mode.label}')),
      ],
      selected: {state.defaultMode},
      onSelectionChanged: (selection) => state.setDefaultMode(selection.first),
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        backgroundColor: AppColors.surface,
        selectedBackgroundColor: AppColors.primary,
        foregroundColor: AppColors.textSecondary,
        selectedForegroundColor: Colors.white,
      ),
    );
  }

  Widget _missionCard(DailyMission mission) {
    final progress = mission.progress(state.todayReps);
    final done = progress >= 1;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('🎯', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Misión del día: ${mission.targetReps} push-ups',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '${state.todayReps}/${mission.targetReps}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: done ? AppColors.success : AppColors.accent,
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
                  ? '¡Misión completada! 🎉'
                  : 'Complétala hoy y gana +50 XP extra.',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _navCard(
            icon: Icons.emoji_events,
            label: 'Desafíos',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ChallengesScreen(state: state)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _navCard(
            icon: Icons.bar_chart,
            label: 'Estadísticas',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => StatsScreen(state: state)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _navCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            children: [
              Icon(icon, color: AppColors.accent, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

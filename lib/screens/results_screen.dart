import 'package:flutter/material.dart';
import 'package:pushquest_logic/pushquest_logic.dart';

import '../state/game_state.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_card.dart';
import 'workout_screen.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key, required this.result, required this.state});

  final WorkoutApplyResult result;
  final GameState state;

  @override
  Widget build(BuildContext context) {
    final session = result.session;
    final levelUp = result.levelAfter > result.levelBefore;
    return Scaffold(
      appBar: AppBar(title: const Text('Resultados')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${session.reps}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  height: 1,
                ),
              ),
              Text(
                'push-ups · ${session.mode.label}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              if (levelUp)
                _banner(
                  icon: '⭐',
                  text: '¡Subiste al nivel ${result.levelAfter}!',
                  color: AppColors.warning,
                ),
              if (result.missionCompleted) ...[
                const SizedBox(height: 10),
                _banner(
                  icon: '🎯',
                  text:
                      '¡Misión del día completada! +${result.missionBonus} XP',
                  color: AppColors.success,
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'Puntos',
                      value: '${session.points}',
                      icon: Icons.bolt,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      label: 'Mejor combo',
                      value: 'x${session.bestCombo}',
                      icon: Icons.link,
                      accent: AppColors.accent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: 'Duración',
                      value:
                          '${(session.durationSeconds ~/ 60).toString().padLeft(2, '0')}:'
                          '${(session.durationSeconds % 60).toString().padLeft(2, '0')}',
                      icon: Icons.timer,
                      accent: AppColors.accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      label: 'XP total',
                      value: '${state.stats.totalXp}',
                      icon: Icons.trending_up,
                      accent: AppColors.success,
                    ),
                  ),
                ],
              ),
              if (result.newlyUnlocked.isNotEmpty) ...[
                const SizedBox(height: 20),
                _achievementsSection(context),
              ],
              const SizedBox(height: 28),
              FilledButton(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => WorkoutScreen(
                      state: state,
                      mode: session.mode,
                      placement: session.placement,
                    ),
                  ),
                ),
                child: const Text('ENTRENAR DE NUEVO'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  foregroundColor: AppColors.textPrimary,
                ),
                child: const Text('Volver al inicio'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _banner({
    required String icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _achievementsSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '¡Nuevos logros!',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            for (final a in result.newlyUnlocked) ...[
              Row(
                children: [
                  Text(a.icon, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      a.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.success,
                    size: 20,
                  ),
                ],
              ),
              if (a != result.newlyUnlocked.last) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

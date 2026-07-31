import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:pushquest_logic/pushquest_logic.dart';

import '../game/session.dart';
import '../state/game_state.dart';
import '../theme/app_theme.dart';
import '../widgets/stat_card.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key, required this.state});

  final GameState state;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final stats = state.stats;
        final level = state.levelInfo;
        final sessions = state.sessions;
        return Scaffold(
          appBar: AppBar(title: const Text('Estadísticas')),
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Nivel ${level.level}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              '${level.xpIntoLevel}/${level.xpForNext} XP',
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
                            valueColor: const AlwaysStoppedAnimation(
                              AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${Levels.titleFor(level.level)} · '
                          '${state.unlockedAchievements.length}/${AchievementCatalog.all.length} logros',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _chartCard(sessions),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.7,
                  children: [
                    StatCard(
                      label: 'Push-ups totales',
                      value: '${stats.totalReps}',
                      icon: Icons.fitness_center,
                    ),
                    StatCard(
                      label: 'Sesiones',
                      value: '${stats.sessionsCount}',
                      icon: Icons.history,
                      accent: AppColors.accent,
                    ),
                    StatCard(
                      label: 'XP total',
                      value: '${stats.totalXp}',
                      icon: Icons.trending_up,
                      accent: AppColors.success,
                    ),
                    StatCard(
                      label: 'Mejor combo',
                      value: 'x${stats.bestCombo}',
                      icon: Icons.link,
                      accent: AppColors.accent,
                    ),
                    StatCard(
                      label: 'Racha (días)',
                      value: '${stats.streakDays}',
                      icon: Icons.local_fire_department,
                      accent: AppColors.warning,
                    ),
                    StatCard(
                      label: 'Días activos',
                      value: '${stats.daysActive}',
                      icon: Icons.calendar_month,
                      accent: AppColors.accent,
                    ),
                    StatCard(
                      label: 'Reps en piso',
                      value: '${stats.floorReps}',
                      icon: Icons.terrain,
                      accent: AppColors.accent,
                    ),
                    StatCard(
                      label: 'Reps en paralelas',
                      value: '${stats.parallettesReps}',
                      icon: Icons.sports_gymnastics,
                      accent: AppColors.accent,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _chartCard(List<SessionRecord> sessions) {
    final recent = sessions.length > 14
        ? sessions.sublist(sessions.length - 14)
        : sessions;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Últimas sesiones',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            if (recent.isEmpty)
              const Text(
                'Aún no hay datos. ¡Haz tu primera sesión!',
                style: TextStyle(color: AppColors.textSecondary),
              )
            else
              SizedBox(
                height: 160,
                child: BarChart(
                  BarChartData(
                    maxY: _maxReps(recent).toDouble(),
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) =>
                          const FlLine(color: Color(0xFF262E3A)),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: recent.length > 1,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= recent.length) {
                              return const SizedBox.shrink();
                            }
                              final m = recent[index].mode;
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  switch (m) {
                                    PushUpMode.floor => 'p',
                                    PushUpMode.parallettes => 'P',
                                    PushUpMode.free => 'L',
                                  },
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              );
                          },
                        ),
                      ),
                    ),
                    barGroups: [
                      for (var i = 0; i < recent.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: recent[i].reps.toDouble(),
                              color: switch (recent[i].mode) {
                                PushUpMode.floor => AppColors.primary,
                                PushUpMode.parallettes => AppColors.accent,
                                PushUpMode.free => AppColors.success,
                              },
                              width: 12,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  int _maxReps(List<SessionRecord> sessions) {
    var max = 1;
    for (final s in sessions) {
      if (s.reps > max) max = s.reps;
    }
    return max;
  }
}

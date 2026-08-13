import 'package:flutter/material.dart';
import 'package:pushquest_logic/pushquest_logic.dart';

import '../state/game_state.dart';
import '../theme/app_theme.dart';
import '../widgets/confetti_burst.dart';
import '../widgets/haptics.dart';
import '../widgets/responsive.dart';
import '../widgets/stat_card.dart';
import 'workout_screen.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key, required this.result, required this.state});

  final WorkoutApplyResult result;
  final GameState state;

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  bool get _isRecord {
    final reps = widget.result.session.reps;
    return reps > 0 && reps >= widget.state.stats.bestSessionReps;
  }

  bool get _celebrate =>
      widget.result.levelAfter > widget.result.levelBefore ||
      widget.result.missionCompleted ||
      _isRecord;

  @override
  void initState() {
    super.initState();
    if (_celebrate) Haptics.celebrate();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final session = result.session;
    final levelUp = result.levelAfter > result.levelBefore;
    return Scaffold(
      appBar: AppBar(title: const Text('Resultados')),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${session.reps}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 72,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    'push-ups · ${session.mode.label}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: AppSizes.font(context, 18),
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (levelUp) _avatarCelebration(),
                  if (_isRecord) ...[
                    _banner(
                      icon: '🏆',
                      text: '¡Nuevo récord personal!',
                      color: AppColors.warning,
                    ),
                    const SizedBox(height: 10),
                  ],
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
                  _statGrid([
                    StatCard(
                      label: 'Puntos',
                      value: '${session.points}',
                      icon: Icons.bolt,
                    ),
                    StatCard(
                      label: 'Mejor combo',
                      value: 'x${session.bestCombo}',
                      icon: Icons.link,
                      accent: AppColors.accent,
                    ),
                    StatCard(
                      label: 'Duración',
                      value:
                          '${(session.durationSeconds ~/ 60).toString().padLeft(2, '0')}:'
                          '${(session.durationSeconds % 60).toString().padLeft(2, '0')}',
                      icon: Icons.timer,
                      accent: AppColors.accent,
                    ),
                    StatCard(
                      label: 'XP total',
                      value: '${widget.state.stats.totalXp}',
                      icon: Icons.trending_up,
                      accent: AppColors.success,
                    ),
                  ]),
                  if (result.newlyUnlocked.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _achievementsSection(context),
                  ],
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => WorkoutScreen(
                          state: widget.state,
                          mode: session.mode,
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
          if (_celebrate)
            Positioned.fill(
              child: ConfettiBurst(),
            ),
        ],
      ),
    );
  }

  Widget _avatarCelebration() {
    final avatar = widget.state.avatar;
    return Column(
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.4, end: 1.0),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: Color(avatar.color),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(avatar.emoji, style: const TextStyle(fontSize: 48)),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${avatar.name} · Nivel ${widget.state.levelInfo.level}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _statGrid(List<StatCard> cards) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = AppSizes.cardWidth(constraints.maxWidth);
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final card in cards)
              SizedBox(width: width, child: card),
          ],
        );
      },
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
            for (final a in widget.result.newlyUnlocked) ...[
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
              if (a != widget.result.newlyUnlocked.last)
                const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

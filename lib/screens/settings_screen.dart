import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/game_state.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.state});

  final GameState state;

  static String _sensitivityLabel(int value) {
    if (value <= 30) return 'Suave';
    if (value >= 70) return 'Sensible';
    return 'Equilibrada';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Ajustes')),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                  child: SwitchListTile(
                    title: const Text(
                      'Vibración',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: const Text(
                      'Retroalimentación al contar reps, combos y logros.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    value: state.hapticsEnabled,
                    onChanged: (value) {
                      HapticFeedback.lightImpact();
                      state.setHapticsEnabled(value);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Sensibilidad del mini juego',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              _sensitivityLabel(state.arcadeSensitivity),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.accent,
                              ),
                            ),
                          ],
                        ),
                        Slider(
                          value: state.arcadeSensitivity.toDouble(),
                          min: 0,
                          max: 100,
                          divisions: 10,
                          label:
                              _sensitivityLabel(state.arcadeSensitivity),
                          onChanged: (value) {
                            state.setArcadeSensitivity(value.round());
                          },
                        ),
                        const Text(
                          'Extiende los brazos para subir y flexiona para '
                          'bajar. Baja la sensibilidad si el pájaro tiembla '
                          'o se siente brusco.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'PushQuest usa la cámara frontal para detectar tu cuerpo. '
                    'El video se procesa en tiempo real en tu dispositivo y '
                    'no se graba ni se sube a ningún lado.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

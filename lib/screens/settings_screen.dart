import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/game_state.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.state});

  final GameState state;

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

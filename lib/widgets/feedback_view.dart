import 'package:flutter/material.dart';
import 'package:pushquest_logic/pushquest_logic.dart';

import '../theme/app_theme.dart';

(String, Color) feedbackFor(FrameUpdate update) {
  switch (update.feedback) {
    case FeedbackKind.notVisible:
      return ('Colócate frente a la cámara', AppColors.textSecondary);
    case FeedbackKind.notPlank:
      return ('Cadera alta: mantén la plancha', AppColors.warning);
    case FeedbackKind.hipSag:
      return ('No hundas la cadera', AppColors.warning);
    case FeedbackKind.hipPike:
      return ('No eleves la cadera', AppColors.warning);
    case FeedbackKind.needDeeper:
      return ('Baja hasta el fondo', AppColors.primary);
    case FeedbackKind.good:
      return (
        update.phase == CounterPhase.down
            ? '¡Bien! Sigue'
            : 'Prepara la bajada',
        AppColors.accent,
      );
    case FeedbackKind.great:
      return ('¡PERFECTO!', AppColors.success);
  }
}

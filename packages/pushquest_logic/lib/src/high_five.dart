import 'dart:math' as math;

import 'pose_data.dart';

/// Detecta el gesto de "choca esos cinco" para detener el contador:
/// la persona levanta una mano por encima de la línea de los hombros
/// durante un tiempo sostenido.
///
/// El gesto se considera confirmado solo si la mano se mantiene arriba
/// el tiempo mínimo indicado, para evitar disparos accidentales durante
/// las repeticiones (en una lagartija las muñecas nunca superan los hombros).
class HighFiveDetector {
  HighFiveDetector({
    this.sustainSeconds = 1.0,
    this.debounceSeconds = 2.0,
  });

  final double sustainSeconds;
  final double debounceSeconds;

  double _upTime = 0;
  double _cooldown = 0;
  bool _triggered = false;

  bool get triggered => _triggered;

  void reset() {
    _upTime = 0;
    _cooldown = 0;
    _triggered = false;
  }

  /// Alimenta el detector con la pose actual. Devuelve true una única vez
  /// cuando el gesto queda confirmado, y vuelve a armarse tras el debounce.
  bool update(PoseData pose, double dt) {
    if (dt <= 0) return _triggered;
    if (_triggered) {
      _cooldown += dt;
      if (_cooldown >= debounceSeconds) {
        _triggered = false;
        _cooldown = 0;
      }
      return false;
    }

    if (_handUp(pose)) {
      _upTime += dt;
    } else {
      _upTime = 0;
    }

    if (_upTime >= sustainSeconds) {
      _triggered = true;
      _upTime = 0;
    }
    return _triggered;
  }

  bool _handUp(PoseData pose) {
    final shoulderL = pose.leftShoulder;
    final shoulderR = pose.rightShoulder;
    final shoulderY = math.min(
      shoulderL.visible ? shoulderL.y : double.infinity,
      shoulderR.visible ? shoulderR.y : double.infinity,
    );
    if (!shoulderY.isFinite) return false;

    final wristL = pose.leftWrist;
    final wristR = pose.rightWrist;
    return (wristL.visible && wristL.y < shoulderY) ||
        (wristR.visible && wristR.y < shoulderY);
  }
}

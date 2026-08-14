import 'dart:math' as math;

import 'pose_data.dart';

/// Normaliza la altura de la cabeza (nariz) a una señal de profundidad 0..1
/// con el rango de movimiento real del usuario muestreado durante la cuenta
/// atrás: 0 = cabeza arriba, 1 = cabeza abajo.
///
/// Sin un rango muestreado válido cae a un mapeo fijo por defecto
/// ([defaultMin]/[defaultMax]) para que el control siga funcionando aunque el
/// usuario no se mueva durante la calibración.
class HeadCalibrator {
  HeadCalibrator({
    this.defaultMin = 0.15,
    this.defaultMax = 0.85,
    this.minRange = 0.1,
  });

  /// Límites de nose.y usados cuando no hay un rango calibrado útil.
  final double defaultMin;
  final double defaultMax;

  /// Recorrido mínimo de nose.y (coordenada normalizada) para que el rango
  /// muestreado en la cuenta atrás se considere útil.
  final double minRange;

  double? _minY;
  double? _maxY;

  /// Reinicia la calibración (nueva partida / nueva sesión).
  void reset() {
    _minY = null;
    _maxY = null;
  }

  /// Muestrea la altura de la nariz para acotar el rango real. Solo usa
  /// frames con la cara visible.
  void sample(PoseData pose) {
    final nose = pose.nose;
    if (!nose.visible) return;
    _minY = _minY == null ? nose.y : math.min(_minY!, nose.y);
    _maxY = _maxY == null ? nose.y : math.max(_maxY!, nose.y);
  }

  /// Si la calibración de la cuenta atrás reunió un recorrido suficiente.
  bool get calibrated {
    final minY = _minY;
    final maxY = _maxY;
    return minY != null && maxY != null && maxY - minY >= minRange;
  }

  /// Verdadero si la cara del jugador es visible en [pose].
  bool faceVisible(PoseData pose) => pose.nose.visible;

  /// Profundidad de la cabeza 0..1 (0 = arriba, 1 = abajo). Usa el rango
  /// calibrado si está disponible; si no, el mapeo fijo por defecto. Con la
  /// cara fuera de cuadro devuelve 0.5 (neutro).
  double headDepth(PoseData pose) {
    final nose = pose.nose;
    if (!nose.visible) return 0.5;
    final minY = _minY;
    final maxY = _maxY;
    if (minY != null && maxY != null && maxY - minY >= minRange) {
      return ((nose.y - minY) / (maxY - minY)).clamp(0.0, 1.0);
    }
    return ((nose.y - defaultMin) / (defaultMax - defaultMin)).clamp(0.0, 1.0);
  }
}

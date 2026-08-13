/// Calibración del rango real de movimiento del usuario en la vista frontal.
///
/// `upSignal` es el dropRatio con los brazos extendidos (arriba) y `downSignal`
/// el del punto más profundo de la flexión (abajo). El contador deriva sus
/// umbrales de este rango en lugar de usar valores fijos, de modo que el conteo
/// se ajusta al cuerpo de quien entrena y no cuenta reps que no llegan a su
/// rango real de movimiento.
class DepthCalibration {
  const DepthCalibration({
    required this.upSignal,
    required this.downSignal,
    required this.calibratedAt,
  });

  final double upSignal;
  final double downSignal;
  final DateTime calibratedAt;

  /// Rango mínimo de movimiento para que la calibración sea útil.
  static const double minRange = 0.2;

  bool get isValid =>
      upSignal - downSignal >= minRange &&
      upSignal <= 1.05 &&
      downSignal >= -0.2;

  Map<String, dynamic> toJson() => {
        'up': upSignal,
        'down': downSignal,
        'at': calibratedAt.toIso8601String(),
      };

  factory DepthCalibration.fromJson(Map<String, dynamic> json) {
    return DepthCalibration(
      upSignal: (json['up'] as num).toDouble(),
      downSignal: (json['down'] as num).toDouble(),
      calibratedAt:
          DateTime.tryParse(json['at'] as String? ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

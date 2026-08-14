import 'dart:math' as math;

import 'geometry.dart';
import 'pose_data.dart';

class BodyAnalysis {
  const BodyAnalysis({
    required this.bodyVisible,
    required this.sagRatio,
    required this.plank,
    required this.plankRatio,
    required this.dropRatio,
  });

  final bool bodyVisible;
  final double sagRatio;
  final bool plank;
  final double plankRatio;

  /// Qué tan bajaron los hombros hacia las muñecas, normalizado por el torso
  /// (1 = brazos estirados, ~0 = pecho al suelo).
  final double dropRatio;
}

class Quality {
  const Quality({
    required this.depthRatio,
    required this.straightness,
    required this.isGood,
  });

  final double depthRatio;
  final double straightness;
  final bool isGood;
}

/// Límites para la caída/elevación de cadera. Se comparten entre la evaluación
/// de calidad y el feedback en vivo para que avisen y degraden a la vez.
const double sagOkMax = 0.12;
const double sagOkMin = -0.10;
const double sagFailMax = 0.35;
const double sagFailMin = -0.30;

Joint _mid(Joint a, Joint b) {
  return Joint(
    (a.x + b.x) / 2,
    (a.y + b.y) / 2,
    (a.visibility + b.visibility) / 2,
  );
}

Joint? _visible(Joint a, Joint b) {
  if (a.visible && b.visible) return _mid(a, b);
  if (a.visible) return a;
  if (b.visible) return b;
  return null;
}

/// Analiza el cuerpo en la vista frontal. La señal de profundidad es la caída
/// de los hombros hacia las muñecas normalizada por la distancia hombros→caderas.
///
/// La forma se mide con la desviación vertical de la cadera respecto a la línea
/// hombros→tobillos ([sagRatio]): positiva = cadera hundida (sag), negativa =
/// elevada (pike). Sin tobillos visibles no hay referencia de plancha, así que
/// se asume la posición correcta y solo se evalúa la profundidad.
BodyAnalysis analyzeBody(PoseData pose) {
  final shoulders = _visible(pose.leftShoulder, pose.rightShoulder);
  final wrists = _visible(pose.leftWrist, pose.rightWrist);
  final hips = _visible(pose.leftHip, pose.rightHip);

  const notVisible = BodyAnalysis(
    bodyVisible: false,
    sagRatio: 0,
    plank: false,
    plankRatio: 0,
    dropRatio: 0,
  );

  if (shoulders == null || wrists == null || hips == null) {
    return notVisible;
  }
  // La distancia euclídea hombros→caderas es casi constante durante la rep;
  // la altura vertical (hips.y - shoulders.y) colapsa a ~0 e incluso se vuelve
  // negativa al fondo, lo que hacía la señal inestable y doblaba el conteo.
  final torso = distance(shoulders, hips);
  if (torso <= 0.001) return notVisible;
  final dropRatio = (wrists.y - shoulders.y) / torso;

  final ankles = _visible(pose.leftAnkle, pose.rightAnkle);
  if (ankles == null) {
    return BodyAnalysis(
      bodyVisible: true,
      sagRatio: 0,
      plank: true,
      plankRatio: 0,
      dropRatio: dropRatio,
    );
  }

  final sagRatio = _hipDeviation(hips, shoulders, ankles);
  final plankRatio = straightnessFromSag(sagRatio);
  return BodyAnalysis(
    bodyVisible: true,
    sagRatio: sagRatio,
    plank: plankRatio >= 0.5,
    plankRatio: plankRatio,
    dropRatio: dropRatio,
  );
}

/// Desviación vertical de la cadera respecto a la línea hombros→tobillos,
/// normalizada por la longitud de esa línea (coordenadas y hacia abajo):
/// positiva = cadera hundida, negativa = cadera elevada. Se usa la proyección
/// vertical (no la distancia perpendicular) para que sea estable aunque la
/// pose frontal venga ligeramente rotada.
double _hipDeviation(Joint hips, Joint shoulders, Joint ankles) {
  final dx = ankles.x - shoulders.x;
  final dy = ankles.y - shoulders.y;
  final length = math.sqrt(dx * dx + dy * dy);
  if (length <= 0.001) return 0;
  final t = dx.abs() < 1e-4
      ? 0.5
      : ((hips.x - shoulders.x) / dx).clamp(0.0, 1.0);
  final lineY = shoulders.y + t * dy;
  return (hips.y - lineY) / length;
}

/// Evalúa la calidad de la rep completada a partir de la señal mínima alcanzada
/// en el fondo ([minSignal]) y los umbrales de conteo: más cerca del [upThreshold]
/// que del [targetThreshold], más profunda fue la rep.
Quality evaluateQuality({
  required double minSignal,
  required double upThreshold,
  required double targetThreshold,
  required double minStraightness,
}) {
  final depth = ((upThreshold - minSignal) / (upThreshold - targetThreshold))
      .clamp(0.0, 1.0);
  final straight = minStraightness.clamp(0.0, 1.0);
  return Quality(
    depthRatio: depth,
    straightness: straight,
    isGood: depth >= 0.75 && straight >= 0.85,
  );
}

double straightnessFromSag(double sagRatio) {
  if (sagRatio <= sagOkMax && sagRatio >= sagOkMin) return 1.0;
  if (sagRatio > sagOkMax) {
    return math.max(0.0, 1 - (sagRatio - sagOkMax) / (sagFailMax - sagOkMax));
  }
  return math.max(0.0, 1 - (sagOkMin - sagRatio) / (sagOkMin - sagFailMin));
}

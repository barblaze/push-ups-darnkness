import 'dart:math' as math;

import 'package:pushquest_logic/pushquest_logic.dart';

PoseData plankPose({
  required double elbowAngle,
  double sag = 0,
  bool ankles = true,
}) {
  final joints = List<Joint>.generate(33, (i) => const Joint(0, 0, 0));
  const shoulder = Joint(0.3, 0.5);
  const ankle = Joint(0.7, 0.5);
  const elbow = Joint(0.3, 0.62);
  final theta = elbowAngle * math.pi / 180;
  final wrist = Joint(
    0.3 + 0.12 * math.sin(theta),
    0.62 - 0.12 * math.cos(theta),
  );
  const knee = Joint(0.6, 0.5);
  final hipSagged = Joint(0.45, 0.5 + sag * 0.4);

  joints[11] = shoulder;
  joints[12] = shoulder;
  joints[13] = elbow;
  joints[14] = elbow;
  joints[15] = wrist;
  joints[16] = wrist;
  joints[23] = hipSagged;
  joints[24] = hipSagged;
  joints[25] = knee;
  joints[26] = knee;
  if (ankles) {
    joints[27] = ankle;
    joints[28] = ankle;
  }
  return PoseData(joints);
}

/// Cuerpo vertical sobre barras paralelas: hombros y caderas alineados en el
/// eje vertical (sin plancha), con el ángulo de codo controlado.
PoseData parallelPose({
  required double elbowAngle,
  double sag = 0,
  bool ankles = true,
}) {
  final joints = List<Joint>.generate(33, (i) => const Joint(0, 0, 0));
  const shoulder = Joint(0.4, 0.30);
  const ankle = Joint(0.4, 1.0);
  const elbow = Joint(0.4, 0.42);
  final theta = elbowAngle * math.pi / 180;
  final wrist = Joint(
    0.4 + 0.12 * math.sin(theta),
    0.42 - 0.12 * math.cos(theta),
  );
  final hipSagged = Joint(0.4 + sag * 0.4, 0.65);

  joints[11] = shoulder;
  joints[12] = shoulder;
  joints[13] = elbow;
  joints[14] = elbow;
  joints[15] = wrist;
  joints[16] = wrist;
  joints[23] = hipSagged;
  joints[24] = hipSagged;
  if (ankles) {
    joints[27] = ankle;
    joints[28] = ankle;
  }
  return PoseData(joints);
}

PoseData frontPose({required double drop, bool hipsVisible = true}) {
  final joints = List<Joint>.generate(33, (i) => const Joint(0, 0, 0));
  const shoulder = Joint(0.3, 0.4);
  const hip = Joint(0.3, 0.7);
  final torso = hip.y - shoulder.y;
  final wrist = Joint(0.3, shoulder.y + drop * torso);

  joints[11] = shoulder;
  joints[12] = shoulder;
  joints[13] = Joint(0.3, 0.55);
  joints[14] = Joint(0.3, 0.55);
  joints[15] = wrist;
  joints[16] = wrist;
  if (hipsVisible) {
    joints[23] = hip;
    joints[24] = hip;
  }
  return PoseData(joints);
}

/// Vista frontal con geometría realista: las caderas también bajan al flexionar
/// los codos (el builder [frontPose] las mantenía fijas y enmascaraba la
/// inestabilidad de la señal).
PoseData frontPoseReal({required double depth}) {
  final joints = List<Joint>.generate(33, (i) => const Joint(0, 0, 0));
  const wrist = Joint(0.3, 0.75);
  final shoulder = Joint(0.3, 0.45 + depth * 0.30);
  final hip = Joint(0.3, 0.70 + depth * 0.04);

  joints[11] = shoulder;
  joints[12] = shoulder;
  joints[13] = Joint(0.3, 0.62);
  joints[14] = Joint(0.3, 0.62);
  joints[15] = wrist;
  joints[16] = wrist;
  joints[23] = hip;
  joints[24] = hip;
  return PoseData(joints);
}

/// Fondo profundo que disparaba el doble conteo con la antigua normalización:
/// hombros por debajo de las muñecas y caderas apenas por encima de los hombros
/// (la altura vertical hombros→caderas era negativa y casi cero).
PoseData frontBottomPose() {
  final joints = List<Joint>.generate(33, (i) => const Joint(0, 0, 0));
  const shoulder = Joint(0.3, 0.78);
  const wrist = Joint(0.3, 0.75);
  const hip = Joint(0.3, 0.77);

  joints[11] = shoulder;
  joints[12] = shoulder;
  joints[13] = Joint(0.3, 0.62);
  joints[14] = Joint(0.3, 0.62);
  joints[15] = wrist;
  joints[16] = wrist;
  joints[23] = hip;
  joints[24] = hip;
  return PoseData(joints);
}

PoseData highFivePose({required bool handUp}) {
  final joints = List<Joint>.generate(33, (i) => const Joint(0, 0, 0));
  const shoulder = Joint(0.3, 0.6);
  const wristDown = Joint(0.3, 0.75);
  final wristUp = Joint(0.5, 0.3);

  joints[11] = shoulder;
  joints[12] = shoulder;
  joints[13] = Joint(0.3, 0.68);
  joints[14] = Joint(0.3, 0.68);
  joints[15] = handUp ? wristUp : wristDown;
  joints[16] = handUp ? wristUp : wristDown;
  return PoseData(joints);
}

PoseData invisible() =>
    PoseData(List<Joint>.generate(33, (i) => const Joint(0, 0, 0)));

double angleDeg(double deg) => deg;

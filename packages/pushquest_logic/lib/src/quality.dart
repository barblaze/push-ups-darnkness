import 'dart:math' as math;

import 'geometry.dart';
import 'placement.dart';
import 'pose_data.dart';

class BodyAnalysis {
  const BodyAnalysis({
    required this.bodyVisible,
    required this.elbowAngle,
    required this.sagRatio,
    required this.plank,
    required this.plankRatio,
    required this.dropRatio,
  });

  final bool bodyVisible;
  final double elbowAngle;
  final double sagRatio;
  final bool plank;
  final double plankRatio;

  /// Vista frontal: qué tan bajaron los hombros hacia las muñecas,
  /// normalizado por el torso (1 = brazos estirados, ~0 = pecho al suelo).
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

BodyAnalysis analyzeBody(
  PoseData pose, {
  CameraPlacement placement = CameraPlacement.profile,
}) {
  final shoulderL = pose.leftShoulder;
  final shoulderR = pose.rightShoulder;
  final elbowL = pose.leftElbow;
  final elbowR = pose.rightElbow;
  final wristL = pose.leftWrist;
  final wristR = pose.rightWrist;

  final shoulders = _visible(shoulderL, shoulderR);
  final elbows = _visible(elbowL, elbowR);
  final wrists = _visible(wristL, wristR);
  final hips = _visible(pose.leftHip, pose.rightHip);
  final ankles = _visible(pose.leftAnkle, pose.rightAnkle);

  const notVisible = BodyAnalysis(
    bodyVisible: false,
    elbowAngle: 0,
    sagRatio: 0,
    plank: false,
    plankRatio: 0,
    dropRatio: 0,
  );

  final front = placement == CameraPlacement.front;

  if (front) {
    if (shoulders == null || wrists == null || hips == null) {
      return notVisible;
    }
    final torso = hips.y - shoulders.y;
    if (torso.abs() <= 0.001) return notVisible;
    final dropRatio = (wrists.y - shoulders.y) / torso;
    return BodyAnalysis(
      bodyVisible: true,
      elbowAngle: elbows == null ? 180 : angleAt(shoulders, elbows, wrists),
      sagRatio: 0,
      plank: true,
      plankRatio: 0,
      dropRatio: dropRatio,
    );
  }

  if (shoulders == null || elbows == null || wrists == null) {
    return notVisible;
  }

  if (hips == null || ankles == null) {
    return notVisible;
  }

  final elbowAngle = angleAt(shoulders, elbows, wrists);

  final torsoLen = distance(shoulders, ankles);
  if (torsoLen == 0) {
    return notVisible;
  }

  final plankRatio = (shoulders.y - hips.y).abs() / torsoLen;
  final plank = plankRatio <= 0.18;

  final deviation = signedDistanceToLine(hips, shoulders, ankles);
  final orientation = shoulders.x < ankles.x ? 1.0 : -1.0;
  final sagRatio = deviation * orientation / torsoLen;

  return BodyAnalysis(
    bodyVisible: true,
    elbowAngle: elbowAngle,
    sagRatio: sagRatio,
    plank: plank,
    plankRatio: plankRatio,
    dropRatio: 0,
  );
}

Quality evaluateQuality({
  required double minElbowAngle,
  required double upAngle,
  required double targetAngle,
  required double minStraightness,
}) {
  final depth = ((upAngle - minElbowAngle) / (upAngle - targetAngle))
      .clamp(0.0, 1.0);
  final straight = minStraightness.clamp(0.0, 1.0);
  return Quality(
    depthRatio: depth,
    straightness: straight,
    isGood: depth >= 0.75 && straight >= 0.85,
  );
}

double straightnessFromSag(double sagRatio) {
  const okMax = 0.12;
  const okMin = -0.10;
  const failMax = 0.35;
  const failMin = -0.30;
  if (sagRatio <= okMax && sagRatio >= okMin) return 1.0;
  if (sagRatio > okMax) {
    return math.max(0.0, 1 - (sagRatio - okMax) / (failMax - okMax));
  }
  return math.max(0.0, 1 - (okMin - sagRatio) / (okMin - failMin));
}

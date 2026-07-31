import 'dart:math' as math;

import 'package:pushquest_logic/pushquest_logic.dart';

PoseData plankPose({required double elbowAngle, double sag = 0}) {
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
  joints[27] = ankle;
  joints[28] = ankle;
  return PoseData(joints);
}

PoseData invisible() =>
    PoseData(List<Joint>.generate(33, (i) => const Joint(0, 0, 0)));

double angleDeg(double deg) => deg;

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

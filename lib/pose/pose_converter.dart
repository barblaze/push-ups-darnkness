import 'package:flutter_pose_detection/flutter_pose_detection.dart';
import 'package:pushquest_logic/pushquest_logic.dart';

PoseData poseDataFromPlugin(Pose pose) {
  assert(pose.landmarks.length == PoseData.count);
  final joints = List<Joint>.generate(PoseData.count, (index) {
    final landmark = pose.landmarks[index];
    return Joint(landmark.x, landmark.y, landmark.visibility);
  });
  return PoseData(joints);
}

class Joint {
  const Joint(this.x, this.y, [this.visibility = 1.0]);

  final double x;
  final double y;
  final double visibility;

  bool get visible => visibility >= 0.5;
}

class PoseData {
  PoseData(this.joints) : assert(joints.length == 33);

  final List<Joint> joints;

  Joint operator [](int index) => joints[index];

  Joint get nose => joints[0];
  Joint get leftShoulder => joints[11];
  Joint get rightShoulder => joints[12];
  Joint get leftElbow => joints[13];
  Joint get rightElbow => joints[14];
  Joint get leftWrist => joints[15];
  Joint get rightWrist => joints[16];
  Joint get leftHip => joints[23];
  Joint get rightHip => joints[24];
  Joint get leftKnee => joints[25];
  Joint get rightKnee => joints[26];
  Joint get leftAnkle => joints[27];
  Joint get rightAnkle => joints[28];

  static const int count = 33;
}

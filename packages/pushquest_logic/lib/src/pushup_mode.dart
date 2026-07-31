enum PushUpMode { floor, parallettes, free }

extension PushUpModeDetails on PushUpMode {
  String get label => switch (this) {
        PushUpMode.floor => 'Piso',
        PushUpMode.parallettes => 'Paralelas',
        PushUpMode.free => 'Libre',
      };

  String get icon => switch (this) {
        PushUpMode.floor => '🤸',
        PushUpMode.parallettes => '🦾',
        PushUpMode.free => '🏋️',
      };

  String get positionHint => switch (this) {
        PushUpMode.floor => 'Colócate en el suelo y pon la cámara de lado',
        PushUpMode.parallettes => 'Manos sobre las paralelas, cámara de lado',
        PushUpMode.free => 'Haz push-ups a tu ritmo: solo contamos tus reps',
      };

  double get upAngle => 160;

  double get countAngle => switch (this) {
        PushUpMode.floor => 95,
        PushUpMode.parallettes => 75,
        PushUpMode.free => 110,
      };

  double get targetAngle => switch (this) {
        PushUpMode.floor => 80,
        PushUpMode.parallettes => 55,
        PushUpMode.free => 80,
      };
}

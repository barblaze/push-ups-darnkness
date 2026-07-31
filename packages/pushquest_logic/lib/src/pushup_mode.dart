enum PushUpMode { floor, parallettes }

extension PushUpModeDetails on PushUpMode {
  String get label => this == PushUpMode.floor ? 'Piso' : 'Paralelas';

  String get icon => this == PushUpMode.floor ? '🤸' : '🦾';

  String get positionHint =>
      this == PushUpMode.floor
          ? 'Colócate en el suelo y pon la cámara de lado'
          : 'Manos sobre las paralelas, cámara de lado';

  double get upAngle => 160;

  double get countAngle => this == PushUpMode.floor ? 95 : 75;

  double get targetAngle => this == PushUpMode.floor ? 80 : 55;
}

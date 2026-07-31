import 'pushup_mode.dart';

enum CameraPlacement { profile, front }

extension CameraPlacementDetails on CameraPlacement {
  String get label => this == CameraPlacement.profile ? 'Perfil' : 'De frente';

  String get icon => this == CameraPlacement.profile ? '👤' : '🤳';

  String get positionHint => this == CameraPlacement.profile
      ? 'Celular de lado, viendo tu perfil completo'
      : 'Celular vertical y de frente; procura que no se salgan tus pies';
}

double upAngleFor(PushUpMode mode, CameraPlacement placement) =>
    placement == CameraPlacement.front ? 150 : 160;

double countAngleFor(PushUpMode mode, CameraPlacement placement) {
  if (placement == CameraPlacement.front) {
    return switch (mode) {
      PushUpMode.floor => 110,
      PushUpMode.parallettes => 90,
      PushUpMode.free => 115,
    };
  }
  return switch (mode) {
    PushUpMode.floor => 95,
    PushUpMode.parallettes => 75,
    PushUpMode.free => 110,
  };
}

double targetAngleFor(PushUpMode mode, CameraPlacement placement) {
  if (placement == CameraPlacement.front) {
    return switch (mode) {
      PushUpMode.floor => 70,
      PushUpMode.parallettes => 55,
      PushUpMode.free => 80,
    };
  }
  return switch (mode) {
    PushUpMode.floor => 80,
    PushUpMode.parallettes => 55,
    PushUpMode.free => 80,
  };
}

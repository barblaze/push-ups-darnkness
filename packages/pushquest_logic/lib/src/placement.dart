import 'pushup_mode.dart';

enum CameraPlacement { front, profile }

extension CameraPlacementDetails on CameraPlacement {
  String get label => this == CameraPlacement.profile ? 'Perfil' : 'De frente';

  String get icon => this == CameraPlacement.profile ? '👤' : '🤳';

  String get positionHint => this == CameraPlacement.profile
      ? 'Celular de lado, viendo tu perfil completo'
      : 'Celular vertical y de frente; procura que no se salgan tus pies';
}

double upAngleFor(CameraPlacement placement) =>
    placement == CameraPlacement.front ? 150 : 160;

double countAngleFor(PushUpMode mode, CameraPlacement placement) {
  if (placement == CameraPlacement.front) {
    return switch (mode) {
      PushUpMode.floor => 110,
      PushUpMode.parallel => 110,
      PushUpMode.free => 115,
    };
  }
  return switch (mode) {
    PushUpMode.floor => 95,
    PushUpMode.parallel => 105,
    PushUpMode.free => 110,
  };
}

double targetAngleFor(PushUpMode mode, CameraPlacement placement) {
  if (placement == CameraPlacement.front) {
    return switch (mode) {
      PushUpMode.floor => 70,
      PushUpMode.parallel => 70,
      PushUpMode.free => 80,
    };
  }
  return switch (mode) {
    PushUpMode.floor => 80,
    PushUpMode.parallel => 75,
    PushUpMode.free => 80,
  };
}

/// Vista frontal: la señal de conteo es la caída de los hombros hacia las
/// muñecas (dropRatio), no el ángulo de codo, porque el codo se dobla en el
/// plano perpendicular a la cámara y su proyección apenas cambia.
double frontDownDropFor(PushUpMode mode) => switch (mode) {
      PushUpMode.floor => 0.55,
      PushUpMode.parallel => 0.55,
      PushUpMode.free => 0.6,
    };

double frontUpDropFor(PushUpMode mode) => switch (mode) {
      PushUpMode.floor => 0.85,
      PushUpMode.parallel => 0.85,
      PushUpMode.free => 0.8,
    };

double frontTargetDropFor(PushUpMode mode) => switch (mode) {
      PushUpMode.floor => 0.35,
      PushUpMode.parallel => 0.35,
      PushUpMode.free => 0.4,
    };

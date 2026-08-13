import 'pushup_mode.dart';

/// Orientación de la cámara. La app usa únicamente la vista frontal; el valor
/// único se conserva para poder leer datos guardados por versiones anteriores
/// (un `'profile'` viejo se resuelve a `front` al parsear).
enum CameraPlacement { front }

/// Vista frontal: la señal de conteo es la caída de los hombros hacia las
/// muñecas (dropRatio), no el ángulo de codo, porque el codo se dobla en el
/// plano perpendicular a la cámara y su proyección apenas cambia.
double frontDownDropFor(PushUpMode mode) => switch (mode) {
      PushUpMode.floor => 0.55,
      PushUpMode.parallel => 0.55,
      PushUpMode.free || PushUpMode.arcade => 0.6,
    };

double frontUpDropFor(PushUpMode mode) => switch (mode) {
      PushUpMode.floor => 0.85,
      PushUpMode.parallel => 0.85,
      PushUpMode.free || PushUpMode.arcade => 0.8,
    };

double frontTargetDropFor(PushUpMode mode) => switch (mode) {
      PushUpMode.floor => 0.35,
      PushUpMode.parallel => 0.35,
      PushUpMode.free || PushUpMode.arcade => 0.4,
    };

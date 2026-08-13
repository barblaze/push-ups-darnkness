import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

/// Elige un preset de resolución según el tamaño físico de la pantalla.
///
/// Pantallas grandes (flagships) usan alta resolución para mejor detección;
/// pantallas de gama de entrada bajan la resolución para mantener FPS.
ResolutionPreset adaptivePreset() {
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final pixels = view.physicalSize.width * view.physicalSize.height;
  if (pixels >= 2.5 * 1000 * 1000) return ResolutionPreset.high;
  if (pixels >= 1.2 * 1000 * 1000) return ResolutionPreset.medium;
  return ResolutionPreset.low;
}

/// Cámaras ordenadas de preferencia: frontal primero, luego las demás.
CameraDescription selectCamera(List<CameraDescription> cameras) {
  for (final camera in cameras) {
    if (camera.lensDirection == CameraLensDirection.front) return camera;
  }
  return cameras.first;
}

/// Inicializa la cámara probando presets de mayor a menor y formatos de
/// imagen alternativos, devolviendo el primer controlador que funcione.
Future<CameraController> initializeCamera(
  List<CameraDescription> cameras,
) async {
  final camera = selectCamera(cameras);
  final presets = <ResolutionPreset>[
    adaptivePreset(),
    ResolutionPreset.medium,
    ResolutionPreset.low,
  ];

  for (final preset in presets.toSet()) {
    for (final format in <ImageFormatGroup>[
      ImageFormatGroup.nv21,
      ImageFormatGroup.yuv420,
    ]) {
      final controller = CameraController(
        camera,
        preset,
        enableAudio: false,
        imageFormatGroup: format,
      );
      try {
        await controller.initialize();
        return controller;
      } catch (_) {
        await controller.dispose();
      }
    }
  }

  throw CameraSetupException('No se pudo inicializar la cámara.');
}

class CameraSetupException implements Exception {
  CameraSetupException(this.message);

  final String message;

  @override
  String toString() => message;
}

import 'package:camera/camera.dart';
import 'package:flutter_pose_detection/flutter_pose_detection.dart';
import 'package:pushquest_logic/pushquest_logic.dart';

import 'pose_converter.dart';

class PoseDetectorService {
  NpuPoseDetector? _detector;
  AccelerationMode _accelerationMode = AccelerationMode.unknown;

  /// Formato de imagen de la cámara; es constante durante toda la sesión
  /// (se fija en [initializeCamera]), así que solo se deduce en el primer frame.
  String? _format;

  bool get isInitialized => _detector?.isInitialized ?? false;

  AccelerationMode get accelerationMode => _accelerationMode;

  Future<void> initialize() async {
    if (isInitialized) return;
    final detector = NpuPoseDetector(config: PoseDetectorConfig.realtime());
    _accelerationMode = await detector.initialize();
    _detector = detector;
  }

  Future<PoseData?> detectFromCameraImage(
    CameraImage image, {
    required int rotation,
  }) async {
    final detector = _detector;
    if (detector == null || !detector.isInitialized) return null;

    final planes = image.planes
        .map(
          (p) => {
            'bytes': p.bytes,
            'bytesPerRow': p.bytesPerRow,
            'bytesPerPixel': p.bytesPerPixel ?? 1,
          },
        )
        .toList();
    final format = _format ??= switch (image.format.group) {
      ImageFormatGroup.yuv420 => 'yuv420',
      ImageFormatGroup.nv21 => 'nv21',
      _ => 'bgra8888',
    };

    final result = await detector.processFrame(
      planes: planes,
      width: image.width,
      height: image.height,
      format: format,
      rotation: rotation,
    );

    final pose = result.firstPose;
    if (pose == null) return null;
    return poseDataFromPlugin(pose);
  }

  void dispose() {
    _detector?.dispose();
    _detector = null;
    _format = null;
  }
}

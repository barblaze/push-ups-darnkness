import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pushquest_logic/pushquest_logic.dart';

import '../game/camera_setup.dart';
import '../pose/pose_detector_service.dart';
import '../theme/app_theme.dart';
import '../widgets/pose_overlay_painter.dart';

class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({
    super.key,
    this.placement = CameraPlacement.profile,
  });

  final CameraPlacement placement;

  @override
  State<CalibrationScreen> createState() => _CalibrationScreenState();
}

class _CalibrationScreenState extends State<CalibrationScreen> {
  final PoseDetectorService _poseDetector = PoseDetectorService();

  CameraController? _cameraController;
  bool _mirrorPreview = false;
  bool _isInitializing = true;
  bool _isProcessing = false;
  bool _permissionDenied = false;
  String? _fatalError;
  String _status = 'Iniciando…';

  PoseData? _lastPose;
  DateTime? _lastFrameTime;
  double _fps = 0;
  int _frameMs = 0;
  int _processedFrames = 0;
  int _frameWidth = 0;
  int _frameHeight = 0;
  double _signalMin = double.infinity;
  double _signalMax = double.negativeInfinity;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _cameraController?.stopImageStream();
    _cameraController?.dispose();
    _poseDetector.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        setState(() {
          _permissionDenied = true;
          _fatalError =
              'Se necesita permiso de cámara para probar la detección.';
          _isInitializing = false;
        });
        return;
      }
      _permissionDenied = false;

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _fatalError = 'No se encontró ninguna cámara.';
          _isInitializing = false;
        });
        return;
      }

      final controller = await initializeCamera(cameras);
      _cameraController = controller;
      _mirrorPreview =
          controller.description.lensDirection == CameraLensDirection.front;

      await _poseDetector.initialize();

      if (!mounted) return;
      setState(() {
        _isInitializing = false;
        _status =
            'Detector listo (${_poseDetector.accelerationMode.name}) · '
            '${controller.value.previewSize?.width.toInt() ?? 0}x'
            '${controller.value.previewSize?.height.toInt() ?? 0}';
      });

      await controller.startImageStream(_onFrame);
    } catch (e) {
      if (mounted) {
        setState(() {
          _fatalError = 'No se pudo iniciar la cámara: $e';
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_isProcessing || _fatalError != null) return;
    _isProcessing = true;
    try {
      final started = DateTime.now();
      final rotation = _cameraController?.description.sensorOrientation ?? 0;
      final pose = await _poseDetector.detectFromCameraImage(
        image,
        rotation: rotation,
      );
      final frameMs = DateTime.now().difference(started).inMilliseconds;

      final now = DateTime.now();
      final dt = _lastFrameTime == null
          ? 0.0
          : now.difference(_lastFrameTime!).inMilliseconds;
      _lastFrameTime = now;
      if (dt > 0) {
        final instant = 1000 / dt;
        _fps = _fps == 0 ? instant : _fps * 0.8 + instant * 0.2;
      }

      final front = widget.placement == CameraPlacement.front;
      final analysis =
          pose == null ? null : analyzeBody(pose, placement: widget.placement);
      if (analysis != null && analysis.bodyVisible) {
        final signal = front ? analysis.dropRatio : analysis.elbowAngle;
        setState(() {
          if (signal < _signalMin) _signalMin = signal;
          if (signal > _signalMax) _signalMax = signal;
        });
      }

      if (mounted) {
        setState(() {
          _lastPose = pose;
          _frameMs = frameMs;
          _frameWidth = image.width;
          _frameHeight = image.height;
          _processedFrames += 1;
        });
      }
    } catch (_) {
      // Un frame fallido no debe detener la prueba.
    } finally {
      _isProcessing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Probar detección')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_fatalError != null) return _errorView();
    if (_isInitializing) return _loadingView();
    return _cameraView();
  }

  Widget _loadingView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: 16),
          Text(_status, style: const TextStyle(color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 56, color: AppColors.danger),
            const SizedBox(height: 16),
            Text(
              _fatalError!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textPrimary),
            ),
            const SizedBox(height: 24),
            if (_permissionDenied) ...[
              FilledButton.icon(
                onPressed: () => openAppSettings(),
                icon: const Icon(Icons.settings),
                label: const Text('Abrir ajustes'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  setState(() {
                    _isInitializing = true;
                    _fatalError = null;
                  });
                  _init();
                },
                child: const Text('Reintentar'),
              ),
            ] else
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Volver'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cameraView() {
    final controller = _cameraController;
    if (controller == null) return _loadingView();
    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(controller),
        if (_lastPose != null)
          CustomPaint(
            painter: PoseOverlayPainter(
              pose: _lastPose!,
              mirror: _mirrorPreview,
              color: AppColors.accent,
            ),
          ),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: _hudPanel(),
          ),
        ),
      ],
    );
  }

  Widget _hudPanel() {
    final pose = _lastPose;
    final placement = widget.placement;
    final front = placement == CameraPlacement.front;
    final analysis =
        pose == null ? null : analyzeBody(pose, placement: placement);
    final signal = analysis == null
        ? 0.0
        : (front ? analysis.dropRatio : analysis.elbowAngle);
    final upThreshold = front
        ? frontUpDropFor(PushUpMode.floor)
        : upAngleFor(placement);
    final targetThreshold = front
        ? frontTargetDropFor(PushUpMode.floor)
        : targetAngleFor(PushUpMode.floor, placement);
    final depth = analysis == null
        ? 0.0
        : ((upThreshold - signal) / (upThreshold - targetThreshold))
            .clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _status,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _row('FPS', _fps.toStringAsFixed(1)),
          _row('Frame', '$_frameMs ms · $_frameWidth×$_frameHeight'),
          _row(
            'Posición',
            '${placement.icon} ${placement.label}',
            color: AppColors.accent,
          ),
          _row('Procesados', '$_processedFrames frames'),
          const Divider(color: Colors.white24, height: 20),
          if (pose == null)
            const Text(
              'Sin pose detectada. Colócate frente a la cámara.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            )
          else ...[
            _row('Señal', front ? 'Caída hombros' : 'Ángulo codo',
                color: AppColors.accent),
            _row('Profundidad', '${(depth * 100).toStringAsFixed(0)}%'),
            if (front) ...[
              _row(
                'Drop ratio',
                analysis!.dropRatio.toStringAsFixed(3),
              ),
              _row(
                'Umbral cuenta',
                '≤ ${frontDownDropFor(PushUpMode.floor).toStringAsFixed(2)}',
                color: AppColors.warning,
              ),
            ] else ...[
              _row(
                'Ángulo codo',
                '${analysis!.elbowAngle.toStringAsFixed(1)}°',
              ),
              _row(
                'Umbral cuenta',
                '≤ ${countAngleFor(PushUpMode.floor, placement).toStringAsFixed(0)}°',
                color: AppColors.warning,
              ),
              _row('Plancha', analysis.plank ? 'SÍ' : 'no',
                  color: analysis.plank
                      ? AppColors.success
                      : AppColors.danger),
              _row(
                'Plank ratio',
                analysis.plankRatio.toStringAsFixed(3),
                color: analysis.plank
                    ? AppColors.success
                    : AppColors.warning,
              ),
              _row('Cadera (sag)', analysis.sagRatio.toStringAsFixed(3)),
            ],
            const SizedBox(height: 6),
            _signalTracker(front),
            const SizedBox(height: 4),
            Text(
              'Visibilidad: '
              '${_visTag(pose.leftShoulder, pose.rightShoulder, 'hombros')} · '
              '${_visTag(pose.leftElbow, pose.rightElbow, 'codos')} · '
              '${_visTag(pose.leftWrist, pose.rightWrist, 'muñecas')} · '
              '${_visTag(pose.leftHip, pose.rightHip, 'caderas')} · '
              '${_visTag(pose.leftAnkle, pose.rightAnkle, 'tobillos')}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Text(
              front
                  ? 'Haz 2-3 lagartijas: el "Drop ratio" debe bajar y volver a '
                      'subir. Anota FPS y el mínimo del drop ratio.'
                  : 'Haz 2-3 lagartijas: el esqueleto debe seguirte y el ángulo '
                      'de codo bajar. Anota FPS y el ángulo mínimo.',
              style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _signalTracker(bool front) {
    final hasRange =
        _signalMin.isFinite && _signalMax.isFinite && _signalMax > _signalMin;
    if (!hasRange) {
      return const Text(
        'Sin rango todavía: haz al menos 1 lagartija completa.',
        style: TextStyle(color: Colors.white54, fontSize: 12),
      );
    }
    final pose = _lastPose;
    final analysis =
        pose == null ? null : analyzeBody(pose, placement: widget.placement);
    final signal = analysis == null
        ? 0.0
        : (front ? analysis.dropRatio : analysis.elbowAngle);
    final countThreshold = front
        ? frontDownDropFor(PushUpMode.floor)
        : countAngleFor(PushUpMode.floor, widget.placement);
    final suggested = front
        ? _signalMin + (_signalMax - _signalMin) * 0.2
        : _signalMin + 10.0;

    final range = _signalMax - _signalMin;
    final fraction = ((signal - _signalMin) / range).clamp(0.0, 1.0);
    final thresholdFrac =
        ((countThreshold - _signalMin) / range).clamp(0.0, 1.0);
    final isDeep = signal <= countThreshold;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Rango señal',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            Text(
              front
                  ? '${_signalMin.toStringAsFixed(3)} → '
                      '${_signalMax.toStringAsFixed(3)}'
                  : '${_signalMin.toStringAsFixed(0)}° → '
                      '${_signalMax.toStringAsFixed(0)}°',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 14,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: double.infinity,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(7),
                      border: Border.all(color: Colors.white24),
                    ),
                  ),
                  Positioned(
                    left: thresholdFrac * width - 2,
                    child: Container(
                      width: 2,
                      height: 20,
                      color: AppColors.warning,
                    ),
                  ),
                  Positioned(
                    left: fraction * width - 5,
                    top: 1,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isDeep ? AppColors.success : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 1.5),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Mínimo observado',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            Text(
              'Cuenta sugerida ≤ ${front ? suggested.toStringAsFixed(2) : '${suggested.toStringAsFixed(0)}°'}',
              style: const TextStyle(
                color: AppColors.accent,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _visTag(Joint a, Joint b, String label) {
    final visible = (a.visibility >= 0.3 || b.visibility >= 0.3);
    return '$label:${visible ? 'SÍ' : 'no'}';
  }

  Widget _row(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          Text(
            value,
            style: TextStyle(
              color: color ?? Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

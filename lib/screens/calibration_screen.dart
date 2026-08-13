import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pushquest_logic/pushquest_logic.dart';

import '../game/camera_setup.dart';
import '../pose/pose_detector_service.dart';
import '../state/game_state.dart';
import '../theme/app_theme.dart';
import '../widgets/pose_overlay_painter.dart';

/// Pantalla guiada de calibración: captura el rango real de movimiento del
/// usuario (dropRatio con brazos extendidos y en el punto más profundo) y lo
/// guarda para que el conteo y el mini juego se ajusten a su cuerpo.
class CalibrationScreen extends StatefulWidget {
  const CalibrationScreen({super.key, required this.state});

  final GameState state;

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
  double _liveSignal = 0;
  double _signalMin = double.infinity;
  double _signalMax = double.negativeInfinity;
  double _range = 0;
  bool _saving = false;

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
          _fatalError = 'Se necesita permiso de cámara para calibrar.';
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
        _status = 'Calibrando…';
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
      final rotation = _cameraController?.description.sensorOrientation ?? 0;
      final pose = await _poseDetector.detectFromCameraImage(
        image,
        rotation: rotation,
      );
      final analysis = pose == null ? null : analyzeBody(pose);
      final signal = analysis?.bodyVisible == true ? analysis!.dropRatio : 0.0;
      if (analysis?.bodyVisible == true) {
        if (signal < _signalMin) _signalMin = signal;
        if (signal > _signalMax) _signalMax = signal;
        final range = _signalMax - _signalMin;
        if (range >= DepthCalibration.minRange) {
          _range = range;
        }
      }
      if (mounted) {
        setState(() {
          _lastPose = pose;
          _liveSignal = signal;
        });
      }
    } catch (_) {
      // Un frame fallido no debe detener la calibración.
    } finally {
      _isProcessing = false;
    }
  }

  bool get _ready => _range >= DepthCalibration.minRange;

  Future<void> _save() async {
    if (!_ready || _saving) return;
    setState(() => _saving = true);
    await widget.state.saveCalibration(
      DepthCalibration(
        upSignal: _signalMax,
        downSignal: _signalMin,
        calibratedAt: DateTime.now(),
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Calibración guardada: el conteo se ajusta a tu rango.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Calibrar movimiento')),
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
            child: _panel(),
          ),
        ),
      ],
    );
  }

  Widget _panel() {
    final hasRange = _signalMin.isFinite && _signalMax.isFinite;
    final depth = _liveSignal == 0
        ? 0.0
        : ((_signalMax - _liveSignal) / (_signalMax - _signalMin))
            .clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Coloca el celular de frente, entra completo en cuadro y haz 2-3 '
            'lagartijas completas. La app aprende tu rango real de movimiento.',
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
          ),
          const SizedBox(height: 14),
          _row('Cuerpo visible', _lastPose != null ? 'SÍ' : 'no',
              color: _lastPose != null
                  ? AppColors.success
                  : AppColors.danger),
          _row('Profundidad', '${(depth * 100).toStringAsFixed(0)}%'),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: depth.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation(
                depth >= 0.75 ? AppColors.success : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (hasRange)
            _row(
              'Rango aprendido',
              '${_signalMax.toStringAsFixed(2)} → '
                  '${_signalMin.toStringAsFixed(2)}',
              color: AppColors.accent,
            ),
          if (hasRange)
            _row(
              'Cobertura',
              '${(_range * 100).toStringAsFixed(0)}% del mínimo útil '
                  '(${(DepthCalibration.minRange * 100).toStringAsFixed(0)}%)',
              color: _ready ? AppColors.success : AppColors.warning,
            ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _ready ? _save : null,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check),
            label: Text(
              _ready ? 'GUARDAR CALIBRACIÓN' : 'HAZ 2-3 LAGARTIJAS',
            ),
          ),
          if (!_ready)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _range > 0
                    ? '¡Sigue! Aún falta moverte más profundo y volver arriba.'
                    : 'Mueve todo el recorrido: extiende los brazos y baja el pecho.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
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

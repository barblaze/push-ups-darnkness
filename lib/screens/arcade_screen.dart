import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pushquest_logic/pushquest_logic.dart';

import '../game/arcade.dart';
import '../game/camera_setup.dart';
import '../pose/pose_detector_service.dart';
import '../state/game_state.dart';
import '../theme/app_theme.dart';
import '../widgets/arcade_painter.dart';
import '../widgets/confetti_burst.dart';
import '../widgets/haptics.dart';
import '../widgets/pose_overlay_painter.dart';
import 'results_screen.dart';

enum _ArcadePhase { init, countdown, playing, gameOver }

class ArcadeScreen extends StatefulWidget {
  const ArcadeScreen({
    super.key,
    required this.state,
  });

  final GameState state;

  @override
  State<ArcadeScreen> createState() => _ArcadeScreenState();
}

class _ArcadeScreenState extends State<ArcadeScreen>
    with SingleTickerProviderStateMixin {
  final PoseDetectorService _poseDetector = PoseDetectorService();
  late final PushUpCounter _counter;
  final ArcadeGame _game = ArcadeGame();
  final HeadCalibrator _headCal = HeadCalibrator();

  CameraController? _cameraController;
  Ticker? _ticker;
  bool _mirrorPreview = false;
  bool _isInitializing = true;
  bool _isProcessing = false;
  bool _paused = false;
  String? _fatalError;
  bool _permissionDenied = false;

  _ArcadePhase _phase = _ArcadePhase.init;
  int _countdown = 3;
  Timer? _countdownTimer;
  FrameUpdate? _lastUpdate;
  PoseData? _lastPose;
  DateTime? _lastTick;
  DateTime? _sessionStart;
  int _bestCombo = 0;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _counter = PushUpCounter(
      mode: PushUpMode.arcade,
      calibration: widget.state.calibration,
      headCalibrator: _headCal,
    );
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _init();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _countdownTimer?.cancel();
    _ticker?.dispose();
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
              'Se necesita permiso de cámara para controlar el mini juego.';
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

      _ticker = createTicker(_onTick);
      setState(() => _isInitializing = false);
      await controller.startImageStream(_onFrame);
      _ticker!.start();
      _startCountdown();
    } catch (e) {
      if (mounted) {
        setState(() {
          _fatalError = 'No se pudo iniciar la cámara: $e';
          _isInitializing = false;
        });
      }
    }
  }

  void _startCountdown() {
    _headCal.reset();
    setState(() {
      _countdown = 3;
      _phase = _ArcadePhase.countdown;
    });
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_countdown > 1) {
        setState(() => _countdown -= 1);
      } else {
        timer.cancel();
        setState(() {
          _countdown = 0;
          _phase = _ArcadePhase.playing;
          _sessionStart = DateTime.now();
        });
        _game.reset();
        _bestCombo = 0;
      }
    });
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
      if (_phase == _ArcadePhase.playing || _phase == _ArcadePhase.countdown) {
        final p = pose ?? _emptyPose();
        if (_phase == _ArcadePhase.countdown) {
          _headCal.sample(p);
        }
        final update = _counter.update(p);
        _bestCombo = math.max(_bestCombo, update.combo);
        if (update.completedRep != null) Haptics.rep();
        if (update.bodyVisible) {
          // Control 1:1 con la cabeza: arriba sube el pájaro y abajo baja. Si
          // la cara no es visible cae al dropRatio invertido (mismo sentido).
          final analysis = analyzeBody(p);
          _game.feedDepth(
            _headCal.faceVisible(p) ? _headCal.headDepth(p) : 1 - analysis.dropRatio,
          );
        }
        if (mounted) {
          setState(() {
            _lastUpdate = update;
            _lastPose = pose;
          });
        }
      }
    } catch (_) {
      // Un frame fallido no debe detener la partida.
    } finally {
      _isProcessing = false;
    }
  }

  PoseData _emptyPose() => PoseData(
        List.generate(PoseData.count, (_) => const Joint(0, 0, 0)),
      );

  void _onTick(Duration _) {
    if (!mounted || _paused) return;
    final now = DateTime.now();
    final dt = _lastTick == null
        ? 0.0
        : now.difference(_lastTick!).inMilliseconds / 1000;
    _lastTick = now;
    if (dt <= 0) return;

    if (_phase == _ArcadePhase.playing) {
      final update = _lastUpdate;
      final event = _game.update(
        dt.clamp(0.0, 0.05),
        targetAltitude: _game.targetAltitude,
        bodyVisible: update?.bodyVisible ?? false,
      );
      switch (event) {
        case ArcadeEvent.passed:
          Haptics.milestone();
          break;
        case ArcadeEvent.hit:
          if (_game.gameOver) {
            Haptics.celebrate();
            setState(() => _phase = _ArcadePhase.gameOver);
          } else {
            Haptics.milestone();
          }
          break;
        case ArcadeEvent.none:
          break;
      }
      setState(() {});
    }
    if (_phase == _ArcadePhase.gameOver) {
      _game.tick(dt.clamp(0.0, 0.05));
      setState(() {});
    }
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    _ticker?.stop();
    await _cameraController?.stopImageStream();
    await _cameraController?.dispose();
    _cameraController = null;
    _poseDetector.dispose();

    final summary = WorkoutSummary(
      startedAt: _sessionStart ?? DateTime.now(),
      mode: PushUpMode.arcade,
      placement: CameraPlacement.front,
      reps: _counter.reps,
      points: _game.score * 10,
      bestCombo: _bestCombo,
      durationSeconds: _game.elapsed.floor(),
    );
    final result = await widget.state.applyWorkout(summary);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultsScreen(result: result, state: widget.state),
      ),
    );
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _fatalError != null || _phase == _ArcadePhase.gameOver,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(backgroundColor: Colors.black, body: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_fatalError != null) return _errorView();
    if (_isInitializing) return _loadingView();
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
              color: AppColors.accent.withValues(alpha: 0.6),
            ),
          ),
        CustomPaint(
          painter: ArcadePainter(
            game: _game,
            characterColor: Color(widget.state.avatar.color),
            bestScore: widget.state.arcadeBest,
            showDepthGauge: _phase == _ArcadePhase.countdown,
            depthRatio: _game.filteredDepth,
          ),
        ),
        SafeArea(child: _hud()),
        if (_phase == _ArcadePhase.countdown) _countdownOverlay(),
        if (_phase == _ArcadePhase.gameOver) ...[
          _gameOverOverlay(),
          if (_game.score > widget.state.arcadeBest)
            const IgnorePointer(child: ConfettiBurst()),
        ],
        if (_paused && _phase != _ArcadePhase.gameOver) _pauseOverlay(),
      ],
    );
  }

  Widget _hud() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: _togglePause,
                icon: Icon(
                  _paused ? Icons.play_arrow : Icons.pause,
                  color: Colors.white,
                ),
                style: IconButton.styleFrom(backgroundColor: Colors.black45),
              ),
              IconButton(
                onPressed: _confirmExit,
                icon: const Icon(Icons.close, color: Colors.white),
                style: IconButton.styleFrom(backgroundColor: Colors.black45),
              ),
              const Spacer(),
              _hudChip(
                '🏆',
                '${math.max(_game.score, widget.state.arcadeBest)}',
              ),
              const SizedBox(width: 8),
              if (_phase == _ArcadePhase.playing)
                _hudChip(
                  '🤸',
                  '${_counter.reps}',
                ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _hearts(),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _hearts() {
    final remaining = math.max(0, _game.lives);
    return List.filled(3, '🖤')
        .asMap()
        .entries
        .map((e) => e.key < remaining ? '❤️' : '🖤')
        .join(' ');
  }

  Widget _hudChip(String emoji, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black45,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$emoji $text',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _countdownOverlay() {
    final visible = _lastUpdate?.bodyVisible ?? false;
    return IgnorePointer(
      child: Container(
        color: Colors.black.withValues(alpha: 0.5),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'PREPÁRATE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 4),
            TweenAnimationBuilder<double>(
              key: ValueKey(_countdown),
              tween: Tween(begin: 0.7, end: 1),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              builder: (context, value, child) =>
                  Transform.scale(scale: value, child: child),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$_countdown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 110,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                    shadows: [Shadow(color: Colors.black87, blurRadius: 16)],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Arriba subes · abajo bajas',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              visible ? 'Cuerpo visible ✓' : 'Entra en cuadro',
              style: TextStyle(
                color: visible ? AppColors.success : Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gameOverOverlay() {
    final score = _game.score;
    final newBest = score > widget.state.arcadeBest;
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_medal(), style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 8),
            Text(
              'Puntaje: $score',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              newBest ? '¡NUEVO RÉCORD! 🎉' : 'Mejor: ${widget.state.arcadeBest}',
              style: TextStyle(
                color: newBest ? AppColors.warning : Colors.white70,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${_counter.reps} push-ups hechos',
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _replay,
              child: const Text('JUGAR DE NUEVO'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: _finish,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
              ),
              child: const Text('VER RESULTADOS'),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.of(context).popUntil(
                (route) => route.isFirst,
              ),
              child: const Text('Salir'),
            ),
          ],
        ),
      ),
    );
  }

  String _medal() {
    final s = _game.score;
    if (s >= 20) return '👑';
    if (s >= 15) return '🥇';
    if (s >= 10) return '🥈';
    if (s >= 5) return '🥉';
    return '🕊️';
  }

  void _replay() {
    _counter.reset();
    _bestCombo = 0;
    _game.reset();
    _startCountdown();
  }

  Widget _pauseOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.65),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'PAUSA',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _togglePause,
            child: const Text('REANUDAR'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: _confirmExit,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
            ),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
  }

  Widget _loadingView() {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary),
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

  Future<void> _confirmExit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('¿Salir de la partida?'),
        content: const Text(
          'Perderás tu puntaje actual.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Seguir jugando'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      Navigator.of(context).pop();
    }
  }
}

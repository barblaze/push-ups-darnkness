import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pushquest_logic/pushquest_logic.dart';

import '../game/camera_setup.dart';
import '../pose/pose_detector_service.dart';
import '../state/game_state.dart';
import '../theme/app_theme.dart';
import '../widgets/feedback_view.dart';
import '../widgets/haptics.dart';
import '../widgets/pose_overlay_painter.dart';
import 'results_screen.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({
    super.key,
    required this.state,
    required this.mode,
    required this.placement,
  });

  final GameState state;
  final PushUpMode mode;
  final CameraPlacement placement;

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  final PoseDetectorService _poseDetector = PoseDetectorService();
  final HighFiveDetector _highFive = HighFiveDetector();
  late final PushUpCounter _counter;

  static final PoseData _emptyPose = PoseData(
    List.generate(PoseData.count, (_) => const Joint(0, 0, 0)),
  );

  CameraController? _cameraController;
  bool _mirrorPreview = false;
  bool _isInitializing = true;
  bool _isProcessing = false;
  bool _finished = false;
  String? _fatalError;
  String _status = 'Iniciando…';

  bool _counting = false;
  int _countdown = 3;
  Timer? _countdownTimer;
  bool _stoppingByHighFive = false;
  bool _permissionDenied = false;

  DateTime? _sessionStart;
  Timer? _elapsedTimer;
  int _elapsedSeconds = 0;
  int _totalPoints = 0;
  int _bestCombo = 0;

  PoseData? _lastPose;
  FrameUpdate? _lastUpdate;
  DateTime? _lastFrameTime;

  bool _popupVisible = false;
  int _popupPoints = 0;
  bool _popupGreat = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _counter = PushUpCounter(mode: widget.mode, placement: widget.placement);
    _init();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _countdownTimer?.cancel();
    _elapsedTimer?.cancel();
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
              'Se necesita permiso de cámara para contar tus push-ups.';
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
        _status = 'Prepárate';
      });

      await controller.startImageStream(_onFrame);
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
    setState(() {
      _countdown = 3;
      _counting = false;
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
          _counting = true;
          _status = '¡Ya!';
          _sessionStart = DateTime.now();
        });
        _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted || _sessionStart == null) return;
          setState(() {
            _elapsedSeconds =
                DateTime.now().difference(_sessionStart!).inSeconds;
          });
        });
      }
    });
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_isProcessing || _finished || _fatalError != null) return;
    _isProcessing = true;
    try {
      final rotation = _cameraController?.description.sensorOrientation ?? 0;
      final pose = await _poseDetector.detectFromCameraImage(
        image,
        rotation: rotation,
      );

      final now = DateTime.now();
      final dt = _lastFrameTime == null
          ? 0.0
          : now.difference(_lastFrameTime!).inMilliseconds / 1000;
      _lastFrameTime = now;

      if (mounted) setState(() => _lastPose = pose);

      if (!_counting) return;

      if (_highFive.update(pose ?? _emptyPose, dt)) {
        _handleHighFive();
        return;
      }

      final update = _counter.update(
        pose ?? _emptyPose,
        elapsedSinceLastFrame: dt,
      );
      _bestCombo = math.max(_bestCombo, update.combo);

      final completed = update.completedRep;
      if (completed != null && completed.points > 0) {
        _totalPoints += completed.points;
        Haptics.rep();
        SystemSound.play(SystemSoundType.click);
        if (mounted) _showRepPopup(completed);
      }

      if (mounted) {
        setState(() {
          _lastUpdate = update;
        });
      }
    } catch (_) {
      // Un frame fallido no debe detener el entrenamiento.
    } finally {
      _isProcessing = false;
    }
  }

  void _handleHighFive() {
    if (_finished) return;
    setState(() => _stoppingByHighFive = true);
    Haptics.milestone();
    Timer(const Duration(milliseconds: 900), () {
      if (mounted) _finish();
    });
  }

  void _resetSession() {
    setState(() {
      _counter.reset();
      _highFive.reset();
      _totalPoints = 0;
      _bestCombo = 0;
      _elapsedSeconds = 0;
      _sessionStart = DateTime.now();
      _lastPose = null;
      _lastUpdate = null;
      _lastFrameTime = null;
      _popupVisible = false;
    });
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('¿Reiniciar sesión?'),
        content: const Text(
          'Se pondrán las reps, puntos y tiempo en cero.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Reiniciar'),
          ),
        ],
      ),
    );
    if (confirmed == true) _resetSession();
  }

  void _showRepPopup(CompletedRep rep) {
    setState(() {
      _popupVisible = true;
      _popupPoints = rep.points;
      _popupGreat = rep.isGood;
    });
    Timer(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _popupVisible = false);
    });
  }

  Future<void> _finish() async {
    if (_finished) return;
    _finished = true;
    _elapsedTimer?.cancel();
    await _cameraController?.stopImageStream();
    await _cameraController?.dispose();
    _cameraController = null;
    _poseDetector.dispose();

    final summary = WorkoutSummary(
      startedAt: _sessionStart ?? DateTime.now(),
      mode: widget.mode,
      placement: widget.placement,
      reps: _counter.reps,
      points: _totalPoints,
      bestCombo: _bestCombo,
      durationSeconds: _elapsedSeconds,
    );
    final result = await widget.state.applyWorkout(summary);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ResultsScreen(result: result, state: widget.state),
      ),
    );
  }

  Future<void> _confirmFinish() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('¿Terminar sesión?'),
        content: Text(
          widget.mode == PushUpMode.free
              ? '${_counter.reps} reps contadas'
              : '${_counter.reps} reps · $_totalPoints puntos',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Seguir'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Terminar'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _finish();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _fatalError != null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmFinish();
      },
      child: Scaffold(backgroundColor: Colors.black, body: _buildBody()),
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
          child: Column(
            children: [
              _topBar(),
              const Spacer(),
              if (_counting) _repCounter(),
              const Spacer(),
              if (_counting) _feedbackPanel(),
            ],
          ),
        ),
        if (!_counting) _countdownOverlay(),
        if (_stoppingByHighFive) _highFiveOverlay(),
        _repPopup(),
      ],
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: _confirmReset,
            icon: const Icon(Icons.refresh, color: Colors.white),
            style: IconButton.styleFrom(backgroundColor: Colors.black45),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: _confirmFinish,
            icon: const Icon(Icons.close, color: Colors.white),
            style: IconButton.styleFrom(backgroundColor: Colors.black45),
          ),
          const Spacer(),
          _hudChip(
            '⏱',
            '${(_elapsedSeconds ~/ 60).toString().padLeft(2, '0')}:'
                '${(_elapsedSeconds % 60).toString().padLeft(2, '0')}',
          ),
          if (widget.mode != PushUpMode.free) ...[
            const SizedBox(width: 8),
            _hudChip('⚡', '$_totalPoints'),
          ],
          const SizedBox(width: 8),
          _hudChip(widget.mode.icon, widget.mode.label),
        ],
      ),
    );
  }

  Widget _countdownOverlay() {
    final pose = _lastPose;
    final analysis = pose == null
        ? null
        : analyzeBody(pose, placement: widget.placement);
    final bodyOk = analysis?.bodyVisible ?? false;
    final requiresPlank = widget.mode == PushUpMode.floor;
    final positionOk =
        bodyOk && (!requiresPlank || (analysis?.plank ?? false));
    return IgnorePointer(
      child: Container(
        color: Colors.black.withValues(alpha: 0.45),
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$_countdown',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 120,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                    shadows: [Shadow(color: Colors.black87, blurRadius: 16)],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _readyChip('Cuerpo visible', bodyOk, Icons.accessibility_new),
            const SizedBox(height: 8),
            if (requiresPlank)
              _readyChip('En posición de lagartija', positionOk,
                  Icons.sports_gymnastics),
            const SizedBox(height: 24),
            const Text(
              'Termina tu serie con una mano en alto',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _readyChip(String label, bool ok, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: ok ? AppColors.success : Colors.white38),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            ok ? '✓' : '✗',
            style: TextStyle(
              color: ok ? AppColors.success : AppColors.danger,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _highFiveOverlay() {
    return IgnorePointer(
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        alignment: Alignment.center,
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🖐️', style: TextStyle(fontSize: 72)),
            SizedBox(height: 12),
            Text(
              '¡ALTO! Sesión terminada',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
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

  Widget _repCounter() {
    return Column(
      children: [
        TweenAnimationBuilder<double>(
          key: ValueKey(_counter.reps),
          tween: Tween(begin: 1.35, end: 1.0),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Text(
            '${_counter.reps}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 84,
              fontWeight: FontWeight.w900,
              height: 1,
              shadows: [Shadow(color: Colors.black54, blurRadius: 12)],
            ),
          ),
        ),
        Text(
          _bestCombo > 1 ? 'REPS · COMBO x$_bestCombo' : 'REPS',
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _feedbackPanel() {
    final update = _lastUpdate;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.placement == CameraPlacement.profile
                ? widget.mode.positionHint
                : widget.placement.positionHint,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          if (update != null) ...[
            const SizedBox(height: 10),
            _feedbackRow(update),
            const SizedBox(height: 10),
            _depthBar(update),
          ],
          const SizedBox(height: 12),
          _xpRow(),
        ],
      ),
    );
  }

  Widget _xpRow() {
    final level = widget.state.levelInfo;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'NIVEL',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
            Text(
              '${level.level} · ${level.xpIntoLevel}/${level.xpForNext} XP',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TweenAnimationBuilder<double>(
          key: ValueKey('xp-${level.level}'),
          tween: Tween(begin: 0, end: level.progress),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
          builder: (context, value, _) => ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 6,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        ),
      ],
    );
  }

  Widget _feedbackRow(FrameUpdate update) {
    final (message, color) = widget.mode == PushUpMode.free &&
            update.feedback != FeedbackKind.notVisible
        ? ('Sigue contando', AppColors.accent)
        : feedbackFor(update);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          message,
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _depthBar(FrameUpdate update) {
    final depth = update.phase == CounterPhase.down ? update.depthRatio : 0.0;
    final color = depth >= 0.9
        ? AppColors.success
        : depth >= 0.5
            ? AppColors.primary
            : AppColors.danger;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: depth,
        minHeight: 8,
        backgroundColor: Colors.white12,
        valueColor: AlwaysStoppedAnimation(color),
      ),
    );
  }

  Widget _repPopup() {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: _popupVisible ? 1 : 0,
        duration: const Duration(milliseconds: 150),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            decoration: BoxDecoration(
              color: _popupGreat ? AppColors.success : AppColors.accent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _popupGreat
                  ? '¡PERFECTO! +$_popupPoints'
                  : '¡Bien! +$_popupPoints',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

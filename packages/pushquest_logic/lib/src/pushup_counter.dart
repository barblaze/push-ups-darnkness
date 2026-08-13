import 'dart:math' as math;

import 'depth_calibration.dart';
import 'placement.dart';
import 'pose_data.dart';
import 'pushup_mode.dart';
import 'quality.dart';
import 'scoring.dart';

enum CounterPhase { idle, up, down }

enum FeedbackKind { notVisible, needDeeper, hipSag, hipPike, good, great }

class CompletedRep {
  const CompletedRep({
    required this.repNumber,
    required this.depthRatio,
    required this.straightness,
    required this.isGood,
    required this.points,
    required this.combo,
  });

  final int repNumber;
  final double depthRatio;
  final double straightness;
  final bool isGood;
  final int points;
  final int combo;
}

class FrameUpdate {
  const FrameUpdate({
    required this.phase,
    required this.reps,
    required this.combo,
    required this.depthRatio,
    required this.sagRatio,
    required this.feedback,
    required this.bodyVisible,
    this.completedRep,
  });

  final CounterPhase phase;
  final int reps;
  final int combo;
  final double depthRatio;
  final double sagRatio;
  final FeedbackKind feedback;
  final bool bodyVisible;
  final CompletedRep? completedRep;
}

/// Cuenta reps usando la señal de profundidad de la vista frontal (dropRatio).
///
/// Para evitar el sobreconteo por ruido de la pose:
/// - suaviza la señal con un filtro exponencial (EMA);
/// - exige [debounceFrames] frames consecutivos fuera del umbral para cambiar
///   de fase, de modo que un destello de un frame no se cuenta como rep;
/// - con una [DepthCalibration] guardada deriva los umbrales del rango real de
///   movimiento del usuario; sin ella usa valores fijos.
class PushUpCounter {
  PushUpCounter({
    this.mode = PushUpMode.floor,
    DepthCalibration? calibration,
    this.filterStrength = 0.35,
    this.debounceFrames = 3,
  }) : _calibration = calibration {
    _applyCalibration();
  }

  final PushUpMode mode;

  final DepthCalibration? _calibration;

  /// Peso del frame actual en la señal filtrada (0..1; 1 = sin suavizado).
  final double filterStrength;

  /// Frames consecutivos bajo/sobre el umbral necesarios para cambiar de fase.
  final int debounceFrames;

  double _downThreshold = 0;
  double _upThreshold = 0;
  double _targetThreshold = 0;
  bool _hasCalibration = false;

  void _applyCalibration() {
    final cal = _calibration;
    if (cal != null && cal.isValid) {
      final range = cal.upSignal - cal.downSignal;
      _downThreshold = cal.downSignal + range * 0.15;
      _upThreshold = cal.upSignal - range * 0.15;
      _targetThreshold = cal.downSignal;
      _hasCalibration = true;
    } else {
      _downThreshold = frontDownDropFor(mode);
      _upThreshold = frontUpDropFor(mode);
      _targetThreshold = frontTargetDropFor(mode);
      _hasCalibration = false;
    }
  }

  /// Umbral de profundidad para pasar a la fase "abajo" (caída suficiente).
  double get downThreshold => _downThreshold;

  /// Umbral de profundidad para completar la rep (vuelta arriba suficiente).
  double get upThreshold => _upThreshold;

  bool get calibrated => _hasCalibration;

  bool get _requiresPlank => mode == PushUpMode.floor;

  CounterPhase _phase = CounterPhase.up;
  int _reps = 0;
  int _combo = 0;
  double _minSignal = 180;
  double _minStraightness = 1;
  double _liveDepth = 0;
  double _filtered = 0;
  bool _filteredInit = false;
  int _downFrames = 0;
  int _upFrames = 0;

  CounterPhase get phase => _phase;

  int get reps => _reps;

  int get combo => _combo;

  double get liveDepth => _liveDepth;

  void reset() {
    _phase = CounterPhase.up;
    _reps = 0;
    _combo = 0;
    _minSignal = 180;
    _minStraightness = 1;
    _liveDepth = 0;
    _filtered = 0;
    _filteredInit = false;
    _downFrames = 0;
    _upFrames = 0;
  }

  FrameUpdate update(PoseData pose, {double elapsedSinceLastFrame = 0}) {
    if (elapsedSinceLastFrame > 10 && _phase == CounterPhase.up) {
      _combo = 0;
    }

    final analysis = analyzeBody(pose);
    if (!analysis.bodyVisible) {
      _liveDepth = 0;
      return FrameUpdate(
        phase: _phase,
        reps: _reps,
        combo: _combo,
        depthRatio: 0,
        sagRatio: 0,
        feedback: FeedbackKind.notVisible,
        bodyVisible: false,
      );
    }

    final signal = _filterSignal(analysis.dropRatio);

    _liveDepth =
        ((_upThreshold - signal) / (_upThreshold - _targetThreshold))
            .clamp(0.0, 1.0);

    CompletedRep? completedRep;

    if (mode.countsAnyRep) {
      if (_phase == CounterPhase.up) {
        if (signal <= _downThreshold) {
          _downFrames += 1;
          if (_downFrames >= debounceFrames) {
            _phase = CounterPhase.down;
            _downFrames = 0;
          }
        } else {
          _downFrames = 0;
        }
      } else if (_phase == CounterPhase.down) {
        if (signal >= _upThreshold) {
          _upFrames += 1;
          if (_upFrames >= debounceFrames) {
            _reps += 1;
            completedRep = CompletedRep(
              repNumber: _reps,
              depthRatio: _liveDepth,
              straightness: 1,
              isGood: true,
              points: 0,
              combo: 0,
            );
            _phase = CounterPhase.up;
            _upFrames = 0;
          }
        } else {
          _upFrames = 0;
        }
      }
    } else if (!_requiresPlank || analysis.plank) {
      if (_phase == CounterPhase.up) {
        if (signal <= _downThreshold) {
          _downFrames += 1;
          if (_downFrames >= debounceFrames) {
            _phase = CounterPhase.down;
            _downFrames = 0;
            _minSignal = signal;
            _minStraightness = straightnessFromSag(analysis.sagRatio);
          }
        } else {
          _downFrames = 0;
        }
      } else if (_phase == CounterPhase.down) {
        _minSignal = math.min(_minSignal, signal);
        _minStraightness =
            math.min(_minStraightness, straightnessFromSag(analysis.sagRatio));
        if (signal >= _upThreshold) {
          _upFrames += 1;
          if (_upFrames >= debounceFrames) {
            _reps += 1;
            final quality = evaluateQuality(
              minElbowAngle: _minSignal,
              upAngle: _upThreshold,
              targetAngle: _targetThreshold,
              minStraightness: _minStraightness,
            );
            if (quality.isGood) {
              _combo += 1;
            } else {
              _combo = 0;
            }
            completedRep = CompletedRep(
              repNumber: _reps,
              depthRatio: quality.depthRatio,
              straightness: quality.straightness,
              isGood: quality.isGood,
              points: RepScoring.points(quality: quality, combo: _combo),
              combo: _combo,
            );
            _phase = CounterPhase.up;
            _upFrames = 0;
            _minSignal = 180;
            _minStraightness = 1;
          }
        } else {
          _upFrames = 0;
        }
      }
    } else {
      _phase = CounterPhase.up;
      _minSignal = 180;
      _minStraightness = 1;
    }

    final feedback = mode.countsAnyRep
        ? FeedbackKind.good
        : _pickFeedback(analysis);
    return FrameUpdate(
      phase: _phase,
      reps: _reps,
      combo: _combo,
      depthRatio: _liveDepth,
      sagRatio: analysis.sagRatio,
      feedback: feedback,
      bodyVisible: true,
      completedRep: completedRep,
    );
  }

  double _filterSignal(double raw) {
    if (!_filteredInit) {
      _filtered = raw;
      _filteredInit = true;
      return raw;
    }
    _filtered += (raw - _filtered) * filterStrength;
    return _filtered;
  }

  FeedbackKind _pickFeedback(BodyAnalysis analysis) {
    if (analysis.sagRatio > sagOkMax) return FeedbackKind.hipSag;
    if (analysis.sagRatio < sagOkMin) return FeedbackKind.hipPike;
    if (_phase == CounterPhase.down) {
      return _liveDepth >= 0.9 ? FeedbackKind.great : FeedbackKind.good;
    }
    if (_liveDepth > 0.1 && _liveDepth < 0.75) return FeedbackKind.needDeeper;
    return FeedbackKind.good;
  }
}

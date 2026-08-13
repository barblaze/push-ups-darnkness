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
///   de fase, de modo que un destello de un frame no se cuenta como rep.
///
/// Los umbrales se adaptan al rango real de movimiento del usuario:
/// - con una [DepthCalibration] guardada siembran el rango de arranque; sin
///   ella usan valores fijos por modo;
/// - al iniciar cada rep (entrada a la fase "abajo") se re-anclan al fondo y
///   al tope medidos de la rep anterior, de modo que un usuario cuyo rango no
///   alcanza los valores por defecto cuenta igualmente sus reps válidas;
/// - un desatascador baja el umbral "arriba" cuando el usuario lleva varios
///   frames estancado en su tope (p. ej. la primera rep con un tope por debajo
///   del umbral fijo), sin recontar mientras mantiene la postura.
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

  // Rango de referencia: fondo y tope medidos de la última rep completada.
  // Se re-anclan en la entrada de cada fase "abajo" y de ellos se derivan los
  // umbrales, de modo que el conteo se adapta al recorrido real del usuario.
  double _calMin = 0;
  double _calMax = 0;
  double? _lastBottom;
  double _ascentPeak = 0;

  // Desatascador del lado "arriba": detecta que el usuario está estancado en su
  // tope (no logra cruzar [_upThreshold]) y baja el umbral para completar la rep.
  double _peakSinceBottom = 0;
  int _atPeakFrames = 0;

  // Margen con el que se baja el umbral "arriba" al desatascar.
  static const double _adaptiveMargin = 0.05;
  // Subida mínima sobre el fondo para considerar la rep válida al desatascar.
  static const double _minReturn = 0.12;
  // Frames consecutivos estancado en el tope antes de desatascar.
  static const int _stallFrames = 8;
  // Ventana alrededor del pico que cuenta como "en el tope".
  static const double _atPeakBuffer = 0.03;
  // Subida por frame por debajo de la cual el pico se considera estancado.
  static const double _riseDelta = 0.005;
  // Rango mínimo para no degenerar los umbrales derivados.
  static const double _minSpan = 0.05;

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
    _calMin = _targetThreshold;
    _calMax = _upThreshold;
  }

  /// Deriva los umbrales del rango de referencia medido (fondo → "abajo",
  /// tope → "arriba") con el mismo margen del 15% que usa la calibración.
  void _recomputeThresholds() {
    final span = math.max(_calMax - _calMin, _minSpan);
    _downThreshold = _calMin + span * 0.15;
    _upThreshold = _calMax - span * 0.15;
    _targetThreshold = _calMin;
  }

  void _enterUp(double signal) {
    _phase = CounterPhase.up;
    _upFrames = 0;
    _ascentPeak = signal;
  }

  void _enterDown(double signal, {required double straightness}) {
    final bottom = _lastBottom;
    if (bottom != null) {
      _calMin = bottom;
      _calMax = math.max(_ascentPeak, bottom + _minSpan);
      _recomputeThresholds();
    }
    _phase = CounterPhase.down;
    _downFrames = 0;
    _minSignal = signal;
    _minStraightness = straightness;
    _peakSinceBottom = signal;
    _atPeakFrames = 0;
  }

  /// Rastrea el fondo y el pico de la rep en curso y desatasca el umbral
  /// "arriba" si el usuario queda estancado en su tope sin poder cruzar.
  void _adaptUpThreshold(double signal) {
    if (signal < _minSignal) {
      _minSignal = signal;
      _peakSinceBottom = signal;
      _atPeakFrames = 0;
      return;
    }
    if (signal > _peakSinceBottom + _riseDelta) {
      _peakSinceBottom = signal;
      _atPeakFrames = 0;
      return;
    }
    if (signal > _peakSinceBottom) _peakSinceBottom = signal;
    if (signal >= _peakSinceBottom - _atPeakBuffer) {
      _atPeakFrames += 1;
      if (_atPeakFrames >= _stallFrames &&
          _peakSinceBottom - _minSignal >= _minReturn) {
        _upThreshold = _peakSinceBottom - _adaptiveMargin;
      }
    } else {
      _atPeakFrames = 0;
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
    _lastBottom = null;
    _ascentPeak = 0;
    _peakSinceBottom = 0;
    _atPeakFrames = 0;
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
        _ascentPeak = math.max(_ascentPeak, signal);
        if (signal <= _downThreshold) {
          _downFrames += 1;
          if (_downFrames >= debounceFrames) {
            _enterDown(signal, straightness: 1);
          }
        } else {
          _downFrames = 0;
        }
      } else if (_phase == CounterPhase.down) {
        _adaptUpThreshold(signal);
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
            _lastBottom = _minSignal;
            _enterUp(signal);
          }
        } else {
          _upFrames = 0;
        }
      }
    } else if (!_requiresPlank || analysis.plank) {
      if (_phase == CounterPhase.up) {
        _ascentPeak = math.max(_ascentPeak, signal);
        if (signal <= _downThreshold) {
          _downFrames += 1;
          if (_downFrames >= debounceFrames) {
            _enterDown(
              signal,
              straightness: straightnessFromSag(analysis.sagRatio),
            );
          }
        } else {
          _downFrames = 0;
        }
      } else if (_phase == CounterPhase.down) {
        _minStraightness =
            math.min(_minStraightness, straightnessFromSag(analysis.sagRatio));
        _adaptUpThreshold(signal);
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
            _lastBottom = _minSignal;
            _enterUp(signal);
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

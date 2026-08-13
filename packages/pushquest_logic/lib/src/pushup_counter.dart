import 'dart:math' as math;

import 'placement.dart';
import 'pose_data.dart';
import 'pushup_mode.dart';
import 'quality.dart';
import 'scoring.dart';

enum CounterPhase { idle, up, down }

enum FeedbackKind { notVisible, notPlank, needDeeper, hipSag, hipPike, good, great }

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

class PushUpCounter {
  PushUpCounter({
    this.mode = PushUpMode.floor,
    this.placement = CameraPlacement.profile,
  });

  final PushUpMode mode;

  final CameraPlacement placement;

  double get upAngle => upAngleFor(placement);

  double get countAngle => countAngleFor(mode, placement);

  double get targetAngle => targetAngleFor(mode, placement);

  bool get _requiresPlank => mode == PushUpMode.floor;

  CounterPhase _phase = CounterPhase.up;
  int _reps = 0;
  int _combo = 0;
  double _minElbow = 180;
  double _minStraightness = 1;
  double _liveDepth = 0;

  CounterPhase get phase => _phase;

  int get reps => _reps;

  int get combo => _combo;

  double get liveDepth => _liveDepth;

  void reset() {
    _phase = CounterPhase.up;
    _reps = 0;
    _combo = 0;
    _minElbow = 180;
    _minStraightness = 1;
    _liveDepth = 0;
  }

  FrameUpdate update(PoseData pose, {double elapsedSinceLastFrame = 0}) {
    if (elapsedSinceLastFrame > 10 && _phase == CounterPhase.up) {
      _combo = 0;
    }

    final analysis = analyzeBody(pose, placement: placement);
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

    final front = placement == CameraPlacement.front;
    final signal = front ? analysis.dropRatio : analysis.elbowAngle;
    final downThreshold = front ? frontDownDropFor(mode) : countAngle;
    final upThreshold = front ? frontUpDropFor(mode) : upAngle;
    final targetThreshold = front ? frontTargetDropFor(mode) : targetAngle;

    _liveDepth =
        ((upThreshold - signal) / (upThreshold - targetThreshold))
            .clamp(0.0, 1.0);

    CompletedRep? completedRep;

    if (mode.countsAnyRep) {
      if (_phase == CounterPhase.up) {
        if (signal <= downThreshold) {
          _phase = CounterPhase.down;
        }
      } else if (_phase == CounterPhase.down) {
        if (signal >= upThreshold) {
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
        }
      }
    } else if (!_requiresPlank || analysis.plank) {
      if (_phase == CounterPhase.up) {
        if (signal <= downThreshold) {
          _phase = CounterPhase.down;
          _minElbow = signal;
          _minStraightness = straightnessFromSag(analysis.sagRatio);
        }
      } else if (_phase == CounterPhase.down) {
        _minElbow = math.min(_minElbow, signal);
        _minStraightness =
            math.min(_minStraightness, straightnessFromSag(analysis.sagRatio));
        if (signal >= upThreshold) {
          _reps += 1;
          final quality = evaluateQuality(
            minElbowAngle: _minElbow,
            upAngle: upThreshold,
            targetAngle: targetThreshold,
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
          _minElbow = 180;
          _minStraightness = 1;
        }
      }
    } else {
      _phase = CounterPhase.up;
      _minElbow = 180;
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

  FeedbackKind _pickFeedback(BodyAnalysis analysis) {
    if (analysis.sagRatio > sagOkMax) return FeedbackKind.hipSag;
    if (analysis.sagRatio < sagOkMin) return FeedbackKind.hipPike;
    if (_requiresPlank && !analysis.plank) return FeedbackKind.notPlank;
    if (_phase == CounterPhase.down) {
      return _liveDepth >= 0.9 ? FeedbackKind.great : FeedbackKind.good;
    }
    if (_liveDepth > 0.1 && _liveDepth < 0.75) return FeedbackKind.needDeeper;
    return FeedbackKind.good;
  }
}

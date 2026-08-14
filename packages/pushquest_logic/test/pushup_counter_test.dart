import 'package:pushquest_logic/pushquest_logic.dart';
import 'package:test/test.dart';

import 'pose_builder.dart';

PushUpCounter make({
  PushUpMode mode = PushUpMode.floor,
  DepthCalibration? calibration,
  double filterStrength = 0.35,
  int debounceFrames = 3,
  HeadCalibrator? headCalibrator,
}) =>
    PushUpCounter(
      mode: mode,
      calibration: calibration,
      filterStrength: filterStrength,
      debounceFrames: debounceFrames,
      headCalibrator: headCalibrator,
    );

/// Alimenta [pose] [times] veces.
void feed(PushUpCounter c, PoseData pose, [int times = 8]) {
  for (var i = 0; i < times; i++) {
    c.update(pose);
  }
}

/// Alimenta [pose] hasta que se completa una rep (máx. [maxFrames]).
CompletedRep? completeRep(
  PushUpCounter c,
  PoseData pose, {
  int maxFrames = 40,
}) {
  for (var i = 0; i < maxFrames; i++) {
    final update = c.update(pose);
    if (update.completedRep != null) return update.completedRep;
  }
  return null;
}

/// Simula un ciclo completo de push-up suave entre [top] y [bottom] con pasos
/// intermedios (el movimiento real es continuo) y un descanso en el tope.
void fullCycle(
  PushUpCounter c,
  double top,
  double bottom, {
  int dwell = 15,
}) {
  for (final drop in [top, 0.66, 0.60, 0.53, bottom]) {
    feed(c, frontPose(drop: drop), 4);
  }
  for (final drop in [0.58, 0.66, top]) {
    feed(c, frontPose(drop: drop), 4);
  }
  feed(c, frontPose(drop: top), dwell);
}

void main() {
  group('PushUpCounter', () {
    test('counts a clean floor rep', () {
      final counter = make();
      feed(counter, frontPose(drop: 1.0));
      expect(counter.phase, CounterPhase.up);
      feed(counter, frontPose(drop: 0.3));
      expect(counter.phase, CounterPhase.down);
      final rep = completeRep(counter, frontPose(drop: 1.0));
      expect(counter.phase, CounterPhase.up);
      expect(counter.reps, 1);
      expect(rep, isNotNull);
      expect(rep!.isGood, isTrue);
      expect(rep.combo, 1);
      expect(rep.repNumber, 1);
    });

    test('does not count a shallow rep on floor', () {
      final counter = make();
      feed(counter, frontPose(drop: 1.0));
      feed(counter, frontPose(drop: 0.65));
      expect(counter.phase, CounterPhase.up);
      final rep = completeRep(counter, frontPose(drop: 1.0));
      expect(counter.reps, 0);
      expect(rep, isNull);
    });

    test('free mode counts a rep without requiring a plank', () {
      final counter = make(mode: PushUpMode.free);
      feed(counter, frontPose(drop: 1.0));
      feed(counter, frontPose(drop: 0.3));
      expect(counter.phase, CounterPhase.down);
      final rep = completeRep(counter, frontPose(drop: 1.0));
      expect(counter.reps, 1);
      expect(rep, isNotNull);
      expect(rep!.points, 0);
      expect(rep.combo, 0);
      expect(rep.isGood, isTrue);
    });

    test('free mode counts shallower reps', () {
      final counter = make(mode: PushUpMode.free);
      feed(counter, frontPose(drop: 1.0));
      feed(counter, frontPose(drop: 0.4));
      expect(counter.phase, CounterPhase.down);
      final rep = completeRep(counter, frontPose(drop: 1.0));
      expect(counter.reps, 1);
      expect(rep, isNotNull);
    });

    test('encadena combos en reps seguidas', () {
      final counter = make();
      feed(counter, frontPose(drop: 1.0));
      feed(counter, frontPose(drop: 0.3));
      final first = completeRep(counter, frontPose(drop: 1.0));
      expect(first!.combo, 1);
      feed(counter, frontPose(drop: 1.0));
      feed(counter, frontPose(drop: 0.3));
      final second = completeRep(counter, frontPose(drop: 1.0));
      expect(second, isNotNull);
      expect(second!.combo, 2);
    });

    test('combo resets after a long pause', () {
      final counter = make();
      feed(counter, frontPose(drop: 1.0));
      feed(counter, frontPose(drop: 0.3));
      completeRep(counter, frontPose(drop: 1.0));
      expect(counter.combo, 1);
      final update =
          counter.update(frontPose(drop: 1.0), elapsedSinceLastFrame: 12);
      expect(counter.combo, 0);
      expect(update.completedRep, isNull);
    });

    test('reports body not visible', () {
      final counter = make();
      final update = counter.update(invisible());
      expect(update.bodyVisible, isFalse);
      expect(update.feedback, FeedbackKind.notVisible);
    });

    test('feedback needDeeper when half down', () {
      final counter = make();
      final update = counter.update(frontPose(drop: 0.7));
      expect(update.feedback, FeedbackKind.needDeeper);
    });

    test('feedback great when deep in down phase', () {
      final counter = make();
      feed(counter, frontPose(drop: 1.0));
      feed(counter, frontPose(drop: 0.3), 8);
      expect(counter.phase, CounterPhase.down);
      final deep = counter.update(frontPose(drop: 0.3));
      expect(deep.phase, CounterPhase.down);
      expect(deep.feedback, FeedbackKind.great);
    });

    test('front ignores hip sag (no ankles needed)', () {
      final counter = make();
      final update = counter.update(frontPose(drop: 1.0));
      expect(update.feedback, isNot(FeedbackKind.hipSag));
      expect(update.sagRatio, 0.0);
    });

    test('requires hips visible', () {
      final counter = make();
      final update = counter.update(frontPose(drop: 1.0, hipsVisible: false));
      expect(update.bodyVisible, isFalse);
      expect(update.feedback, FeedbackKind.notVisible);
    });

    test('counts exactly one rep per down-up cycle with moving hips', () {
      final counter = make();
      for (final depth in [0.0, 0.2, 0.4, 0.6, 0.8, 1.0, 0.8, 0.6, 0.4, 0.2, 0.0]) {
        feed(counter, frontPoseReal(depth: depth), 5);
      }
      expect(counter.reps, 1);
      expect(counter.phase, CounterPhase.up);
    });

    test('deep bottom with hips above shoulders does not double count', () {
      final counter = make();
      feed(counter, frontPose(drop: 1.0));
      expect(counter.phase, CounterPhase.up);
      feed(counter, frontBottomPose());
      expect(counter.phase, CounterPhase.down);
      final still = counter.update(frontBottomPose());
      expect(counter.reps, 0);
      expect(still.completedRep, isNull);
      final rep = completeRep(counter, frontPose(drop: 1.0));
      expect(counter.reps, 1);
      expect(rep, isNotNull);
    });

    test('shallow rep with moving hips does not count', () {
      final counter = make();
      feed(counter, frontPoseReal(depth: 0.0));
      feed(counter, frontPoseReal(depth: 0.2));
      feed(counter, frontPoseReal(depth: 0.0));
      expect(counter.reps, 0);
    });

    test('reset clears reps and combo', () {
      final counter = make();
      feed(counter, frontPose(drop: 1.0));
      feed(counter, frontPose(drop: 0.3));
      completeRep(counter, frontPose(drop: 1.0));
      expect(counter.reps, 1);
      counter.reset();
      expect(counter.reps, 0);
      expect(counter.combo, 0);
    });

    test('un destello de ruido bajo el umbral no cambia a down', () {
      final counter = make();
      feed(counter, frontPose(drop: 1.0));
      counter.update(frontPose(drop: 0.3));
      feed(counter, frontPose(drop: 1.0));
      expect(counter.phase, CounterPhase.up);
      expect(counter.reps, 0);
    });

    test('un destello de ruido en down no completa la rep antes de tiempo', () {
      final counter = make();
      feed(counter, frontPose(drop: 1.0));
      feed(counter, frontPose(drop: 0.3));
      expect(counter.phase, CounterPhase.down);
      counter.update(frontPose(drop: 1.0));
      feed(counter, frontPose(drop: 0.3));
      final rep = completeRep(counter, frontPose(drop: 1.0));
      expect(counter.reps, 1);
      expect(rep, isNotNull);
    });
  });

  group('PushUpCounter calibración', () {
    test('sin calibración usa los umbrales fijos', () {
      final counter = make();
      expect(counter.calibrated, isFalse);
      expect(counter.downThreshold, closeTo(0.55, 1e-9));
      expect(counter.upThreshold, closeTo(0.85, 1e-9));
    });

    test('deriva los umbrales del rango real del usuario', () {
      final cal = DepthCalibration(
        upSignal: 1.0,
        downSignal: 0.6,
        calibratedAt: DateTime(2026, 8, 1),
      );
      final counter = make(calibration: cal, filterStrength: 1.0);
      expect(counter.calibrated, isTrue);
      // down = 0.6 + 0.15 * 0.4 = 0.66; up = 1.0 - 0.15 * 0.4 = 0.94.
      expect(counter.downThreshold, closeTo(0.66, 1e-9));
      expect(counter.upThreshold, closeTo(0.94, 1e-9));

      feed(counter, frontPose(drop: 1.0));
      feed(counter, frontPose(drop: 0.62));
      expect(counter.phase, CounterPhase.down);
      final rep = completeRep(counter, frontPose(drop: 1.0));
      expect(counter.reps, 1);
      expect(rep, isNotNull);
    });

    test('una bajada fuera del rango real no cuenta con calibración', () {
      final cal = DepthCalibration(
        upSignal: 1.0,
        downSignal: 0.6,
        calibratedAt: DateTime(2026, 8, 1),
      );
      final counter = make(calibration: cal, filterStrength: 1.0);
      feed(counter, frontPose(drop: 1.0));
      feed(counter, frontPose(drop: 0.7));
      expect(counter.phase, CounterPhase.up);
      final rep = completeRep(counter, frontPose(drop: 1.0));
      expect(counter.reps, 0);
      expect(rep, isNull);
    });

    test('calibración inválida cae a los umbrales fijos', () {
      final cal = DepthCalibration(
        upSignal: 0.6,
        downSignal: 0.5,
        calibratedAt: DateTime(2026, 8, 1),
      );
      final counter = make(calibration: cal);
      expect(counter.calibrated, isFalse);
      expect(counter.downThreshold, closeTo(0.55, 1e-9));
      expect(counter.upThreshold, closeTo(0.85, 1e-9));
    });
  });

  group('PushUpCounter parallel', () {
    test('counts a clean dip without requiring a plank', () {
      final counter = make(mode: PushUpMode.parallel);
      feed(counter, frontPose(drop: 1.0));
      expect(counter.phase, CounterPhase.up);
      feed(counter, frontPose(drop: 0.3));
      expect(counter.phase, CounterPhase.down);
      final rep = completeRep(counter, frontPose(drop: 1.0));
      expect(counter.reps, 1);
      expect(rep, isNotNull);
      expect(rep!.isGood, isTrue);
      expect(rep.points, greaterThan(0));
      expect(rep.combo, 1);
    });

    test('does not count a shallow dip', () {
      final counter = make(mode: PushUpMode.parallel);
      feed(counter, frontPose(drop: 1.0));
      feed(counter, frontPose(drop: 0.65));
      expect(counter.phase, CounterPhase.up);
      final rep = completeRep(counter, frontPose(drop: 1.0));
      expect(counter.reps, 0);
      expect(rep, isNull);
    });

    test('parallel never gates on plank', () {
      final counter = make(mode: PushUpMode.parallel);
      final update = counter.update(frontPose(drop: 1.0));
      expect(update.feedback, isNot(FeedbackKind.notVisible));
    });
  });

  group('PushUpCounter re-anclaje', () {
    test('cuenta reps de un usuario cuyo tope no alcanza el umbral fijo', () {
      final counter = make(filterStrength: 1.0);
      expect(counter.upThreshold, closeTo(0.85, 1e-9));

      fullCycle(counter, 0.72, 0.5);
      expect(counter.reps, 1);
      expect(counter.upThreshold, lessThan(0.8));

      fullCycle(counter, 0.72, 0.5);
      fullCycle(counter, 0.72, 0.5);
      expect(counter.reps, 3);

      // El rango se re-ancló al rango medido [0.5, 0.72]: abajo ≈ 0.533,
      // arriba ≈ 0.687.
      expect(counter.upThreshold, closeTo(0.687, 0.02));
      expect(counter.downThreshold, closeTo(0.533, 0.02));
    });

    test('no cuenta reps al mantener la postura o con rebotes pequeños', () {
      final counter = make(filterStrength: 1.0);
      feed(counter, frontPose(drop: 0.72), 60);
      expect(counter.reps, 0);

      feed(counter, frontPose(drop: 0.5), 20);
      for (var i = 0; i < 3; i++) {
        feed(counter, frontPose(drop: 0.55), 6);
        feed(counter, frontPose(drop: 0.5), 6);
      }
      expect(counter.reps, 0);
    });

    test('un ciclo único cuenta exactamente una rep', () {
      final counter = make(filterStrength: 1.0);
      fullCycle(counter, 0.72, 0.5);
      expect(counter.reps, 1);
      expect(counter.phase, CounterPhase.up);
      feed(counter, frontPose(drop: 0.72), 60);
      expect(counter.reps, 1);
    });

    test('la calibración guardada siembra pero el rango se re-ancla a lo medido',
        () {
      final cal = DepthCalibration(
        upSignal: 1.0,
        downSignal: 0.6,
        calibratedAt: DateTime(2026, 8, 1),
      );
      final counter = make(calibration: cal, filterStrength: 1.0);
      expect(counter.downThreshold, closeTo(0.66, 1e-9));
      expect(counter.upThreshold, closeTo(0.94, 1e-9));

      fullCycle(counter, 0.72, 0.5);
      expect(counter.reps, 1);
      fullCycle(counter, 0.72, 0.5);

      // Tras el re-anclaje los umbrales se acercan al rango medido [0.5, 0.72].
      expect(counter.upThreshold, closeTo(0.687, 0.02));
      expect(counter.downThreshold, closeTo(0.533, 0.02));
    });

    test('free/arcade también re-ancla sus umbrales', () {
      final counter = make(mode: PushUpMode.free, filterStrength: 1.0);
      fullCycle(counter, 0.72, 0.5);
      expect(counter.reps, 1);
      fullCycle(counter, 0.72, 0.5);
      fullCycle(counter, 0.72, 0.5);
      expect(counter.reps, 3);
      expect(counter.upThreshold, lessThan(0.8));
    });

    test('un rango más amplio que los umbrales también se re-ancla', () {
      final counter = make(filterStrength: 1.0);
      fullCycle(counter, 0.95, 0.3);
      expect(counter.reps, 1);
      fullCycle(counter, 0.95, 0.3);
      expect(counter.reps, 2);
      // [0.3, 0.95]: abajo = 0.3 + 0.15 * 0.65 = 0.3975, arriba = 0.95 - 0.0975.
      expect(counter.upThreshold, closeTo(0.8525, 0.02));
      expect(counter.downThreshold, closeTo(0.3975, 0.02));
    });
  });

  group('PushUpCounter cabeza', () {
    /// Simula un ciclo completo de push-up moviendo la cabeza entre [topY]
    /// (arriba) y [bottomY] (abajo) con el cuerpo en postura coherente.
    void headCycle(
      PushUpCounter c,
      double topY,
      double bottomY,
    ) {
      for (final f in [0.0, 0.33, 0.5, 0.7, 1.0]) {
        feed(
          c,
          headPose(
            noseY: topY + (bottomY - topY) * f,
            drop: 1.0 - 0.7 * f,
          ),
          4,
        );
      }
      for (final f in [0.6, 0.3, 0.0]) {
        feed(
          c,
          headPose(
            noseY: topY + (bottomY - topY) * f,
            drop: 1.0 - 0.7 * f,
          ),
          4,
        );
      }
      feed(c, headPose(noseY: topY, drop: 1.0), 15);
    }

    test('cuenta reps con la señal de la cabeza calibrada', () {
      final cal = HeadCalibrator();
      final counter = make(
        mode: PushUpMode.free,
        filterStrength: 1.0,
        headCalibrator: cal,
      );
      // Calibración en la cuenta atrás: nariz entre 0.2 (arriba) y 0.8 (abajo).
      cal.sample(headPose(noseY: 0.2, drop: 1.0));
      cal.sample(headPose(noseY: 0.8, drop: 0.3));
      expect(cal.calibrated, isTrue);

      feed(counter, headPose(noseY: 0.2, drop: 1.0));
      expect(counter.phase, CounterPhase.up);
      feed(counter, headPose(noseY: 0.8, drop: 0.3));
      expect(counter.phase, CounterPhase.down);
      final rep = completeRep(counter, headPose(noseY: 0.2, drop: 1.0));
      expect(counter.reps, 1);
      expect(rep, isNotNull);
    });

    test('sin calibrar cae al rango fijo por defecto', () {
      final cal = HeadCalibrator();
      final counter = make(
        mode: PushUpMode.free,
        filterStrength: 1.0,
        headCalibrator: cal,
      );
      expect(cal.calibrated, isFalse);

      feed(counter, headPose(noseY: 0.15, drop: 1.0));
      feed(counter, headPose(noseY: 0.85, drop: 0.3));
      expect(counter.phase, CounterPhase.down);
      final rep = completeRep(counter, headPose(noseY: 0.15, drop: 1.0));
      expect(counter.reps, 1);
      expect(rep, isNotNull);
    });

    test('cae al dropRatio cuando la cara no es visible', () {
      final cal = HeadCalibrator();
      final counter = make(
        mode: PushUpMode.free,
        filterStrength: 1.0,
        headCalibrator: cal,
      );
      cal.sample(headPose(noseY: 0.2, drop: 1.0));
      cal.sample(headPose(noseY: 0.8, drop: 0.3));
      expect(cal.calibrated, isTrue);

      feed(counter, headPose(noseY: 0.5, drop: 1.0, faceVisible: false));
      expect(counter.phase, CounterPhase.up);
      feed(counter, headPose(noseY: 0.5, drop: 0.3, faceVisible: false));
      expect(counter.phase, CounterPhase.down);
      final rep = completeRep(
        counter,
        headPose(noseY: 0.5, drop: 1.0, faceVisible: false),
      );
      expect(counter.reps, 1);
      expect(rep, isNotNull);
    });

    test('el re-anclaje adapta los umbrales a la cabeza', () {
      final cal = HeadCalibrator();
      final counter = make(
        mode: PushUpMode.free,
        filterStrength: 1.0,
        headCalibrator: cal,
      );
      cal.sample(headPose(noseY: 0.35, drop: 1.0));
      cal.sample(headPose(noseY: 0.65, drop: 0.3));
      expect(cal.calibrated, isTrue);

      headCycle(counter, 0.35, 0.65);
      expect(counter.reps, 1);
      headCycle(counter, 0.35, 0.65);
      headCycle(counter, 0.35, 0.65);
      expect(counter.reps, 3);
    });

    test('no cuenta si ni la cara ni el cuerpo son visibles', () {
      final cal = HeadCalibrator();
      final counter = make(
        mode: PushUpMode.free,
        headCalibrator: cal,
      );
      final update = counter.update(invisible());
      expect(update.bodyVisible, isFalse);
      expect(update.feedback, FeedbackKind.notVisible);
      expect(counter.reps, 0);
    });
  });
}

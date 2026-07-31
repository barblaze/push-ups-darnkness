import 'package:pushquest_logic/pushquest_logic.dart';
import 'package:test/test.dart';

import 'pose_builder.dart';

void main() {
  group('PushUpCounter', () {
    test('counts a clean floor rep', () {
      final counter = PushUpCounter(mode: PushUpMode.floor);
      counter.update(plankPose(elbowAngle: 165));
      expect(counter.phase, CounterPhase.up);
      counter.update(plankPose(elbowAngle: 90));
      expect(counter.phase, CounterPhase.down);
      final update = counter.update(plankPose(elbowAngle: 165));
      expect(counter.reps, 1);
      expect(update.completedRep, isNotNull);
      expect(update.completedRep!.isGood, isTrue);
      expect(update.completedRep!.combo, 1);
      expect(update.completedRep!.repNumber, 1);
    });

    test('does not count a shallow rep on floor', () {
      final counter = PushUpCounter(mode: PushUpMode.floor);
      counter.update(plankPose(elbowAngle: 165));
      counter.update(plankPose(elbowAngle: 100));
      expect(counter.phase, CounterPhase.up);
      final update = counter.update(plankPose(elbowAngle: 165));
      expect(counter.reps, 0);
      expect(update.completedRep, isNull);
    });

    test('parallettes requires a deeper rep', () {
      final floorCounter = PushUpCounter(mode: PushUpMode.floor);
      floorCounter.update(plankPose(elbowAngle: 165));
      floorCounter.update(plankPose(elbowAngle: 85));
      final floorUpdate = floorCounter.update(plankPose(elbowAngle: 165));
      expect(floorCounter.reps, 1);
      expect(floorUpdate.completedRep, isNotNull);

      final paraCounter = PushUpCounter(mode: PushUpMode.parallettes);
      paraCounter.update(plankPose(elbowAngle: 165));
      paraCounter.update(plankPose(elbowAngle: 85));
      final paraUpdate = paraCounter.update(plankPose(elbowAngle: 165));
      expect(paraCounter.reps, 0);
      expect(paraUpdate.completedRep, isNull);
    });

    test('does not count when the body is not in a plank', () {
      final counter = PushUpCounter(mode: PushUpMode.floor);
      counter.update(plankPose(elbowAngle: 165));
      counter.update(plankPose(elbowAngle: 90, sag: 0.5));
      final update = counter.update(plankPose(elbowAngle: 165));
      expect(counter.reps, 0);
      expect(update.completedRep, isNull);
    });

    test('free mode counts a rep without requiring a plank', () {
      final counter = PushUpCounter(mode: PushUpMode.free);
      counter.update(plankPose(elbowAngle: 165, sag: 0.5));
      counter.update(plankPose(elbowAngle: 100, sag: 0.5));
      expect(counter.phase, CounterPhase.down);
      final update = counter.update(plankPose(elbowAngle: 165, sag: 0.5));
      expect(counter.reps, 1);
      expect(update.completedRep, isNotNull);
      expect(update.completedRep!.points, 0);
      expect(update.completedRep!.combo, 0);
      expect(update.completedRep!.isGood, isTrue);
    });

    test('free mode counts shallower reps', () {
      final counter = PushUpCounter(mode: PushUpMode.free);
      counter.update(plankPose(elbowAngle: 165));
      counter.update(plankPose(elbowAngle: 105));
      expect(counter.phase, CounterPhase.down);
      final update = counter.update(plankPose(elbowAngle: 165));
      expect(counter.reps, 1);
      expect(update.completedRep, isNotNull);
    });

    test('a sagging rep still counts but breaks the combo', () {
      final counter = PushUpCounter(mode: PushUpMode.floor);
      counter.update(plankPose(elbowAngle: 165));
      counter.update(plankPose(elbowAngle: 90));
      expect(counter.update(plankPose(elbowAngle: 165)).completedRep!.combo, 1);
      counter.update(plankPose(elbowAngle: 165));
      expect(counter.update(plankPose(elbowAngle: 90)).completedRep, isNull);
      expect(counter.update(plankPose(elbowAngle: 165)).completedRep!.combo, 2);

      counter.update(plankPose(elbowAngle: 165));
      counter.update(plankPose(elbowAngle: 90, sag: 0.18));
      final bad = counter.update(plankPose(elbowAngle: 165));
      expect(bad.completedRep, isNotNull);
      expect(bad.completedRep!.isGood, isFalse);
      expect(counter.combo, 0);
    });

    test('combo resets after a long pause', () {
      final counter = PushUpCounter(mode: PushUpMode.floor);
      counter.update(plankPose(elbowAngle: 165));
      counter.update(plankPose(elbowAngle: 90));
      expect(counter.update(plankPose(elbowAngle: 165)).completedRep!.combo, 1);
      final update =
          counter.update(plankPose(elbowAngle: 165), elapsedSinceLastFrame: 12);
      expect(counter.combo, 0);
      expect(update.completedRep, isNull);
    });

    test('reports body not visible', () {
      final counter = PushUpCounter(mode: PushUpMode.floor);
      final update = counter.update(invisible());
      expect(update.bodyVisible, isFalse);
      expect(update.feedback, FeedbackKind.notVisible);
    });

    test('feedback needDeeper when half down', () {
      final counter = PushUpCounter(mode: PushUpMode.floor);
      final update = counter.update(plankPose(elbowAngle: 120));
      expect(update.feedback, FeedbackKind.needDeeper);
    });

    test('feedback great when deep in down phase', () {
      final counter = PushUpCounter(mode: PushUpMode.floor);
      counter.update(plankPose(elbowAngle: 165));
      final update = counter.update(plankPose(elbowAngle: 85));
      expect(update.phase, CounterPhase.down);
      expect(update.feedback, FeedbackKind.great);
    });

    test('feedback hipSag when hips drop', () {
      final counter = PushUpCounter(mode: PushUpMode.floor);
      final update = counter.update(plankPose(elbowAngle: 165, sag: 0.2));
      expect(update.feedback, FeedbackKind.hipSag);
    });

    test('reset clears reps and combo', () {
      final counter = PushUpCounter(mode: PushUpMode.floor);
      counter.update(plankPose(elbowAngle: 165));
      counter.update(plankPose(elbowAngle: 90));
      counter.update(plankPose(elbowAngle: 165));
      expect(counter.reps, 1);
      counter.reset();
      expect(counter.reps, 0);
      expect(counter.combo, 0);
    });

    test('front placement counts a rep without ankles visible', () {
      final counter = PushUpCounter(
        mode: PushUpMode.floor,
        placement: CameraPlacement.front,
      );
      counter.update(frontPose(elbowAngle: 165));
      expect(counter.phase, CounterPhase.up);
      counter.update(frontPose(elbowAngle: 100));
      expect(counter.phase, CounterPhase.down);
      final update = counter.update(frontPose(elbowAngle: 165));
      expect(counter.reps, 1);
      expect(update.completedRep, isNotNull);
      expect(update.bodyVisible, isTrue);
    });

    test('front placement counts a shallower rep (threshold 110)', () {
      final counter = PushUpCounter(
        mode: PushUpMode.floor,
        placement: CameraPlacement.front,
      );
      counter.update(frontPose(elbowAngle: 165));
      counter.update(frontPose(elbowAngle: 105));
      expect(counter.phase, CounterPhase.down);
      final update = counter.update(frontPose(elbowAngle: 165));
      expect(counter.reps, 1);
      expect(update.completedRep, isNotNull);
    });

    test('front placement ignores hip sag without ankles', () {
      final counter = PushUpCounter(
        mode: PushUpMode.floor,
        placement: CameraPlacement.front,
      );
      final update = counter.update(frontPose(elbowAngle: 165));
      expect(update.feedback, isNot(FeedbackKind.hipSag));
      expect(update.sagRatio, 0.0);
    });

    test('profile placement still requires ankles visible', () {
      final counter = PushUpCounter(mode: PushUpMode.floor);
      final update = counter.update(frontPose(elbowAngle: 165));
      expect(update.bodyVisible, isFalse);
      expect(update.feedback, FeedbackKind.notVisible);
    });
  });
}

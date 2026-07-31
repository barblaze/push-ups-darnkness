import 'package:pushquest_logic/pushquest_logic.dart';
import 'package:test/test.dart';

import 'pose_builder.dart';

void main() {
  group('HighFiveDetector', () {
    test('requires a sustained hand above the shoulders', () {
      final detector = HighFiveDetector();
      final up = highFivePose(handUp: true);
      final down = highFivePose(handUp: false);

      detector.update(down, 0.033);
      expect(detector.triggered, isFalse);
      detector.update(up, 0.033);
      expect(detector.triggered, isFalse);
      detector.update(up, 0.5);
      expect(detector.triggered, isFalse);
      detector.update(up, 0.5);
      expect(detector.triggered, isTrue);
    });

    test('resets the counter when the hand goes down', () {
      final detector = HighFiveDetector();
      final up = highFivePose(handUp: true);
      final down = highFivePose(handUp: false);

      detector.update(up, 0.5);
      detector.update(down, 0.5);
      detector.update(down, 0.1);
      expect(detector.triggered, isFalse);
      detector.update(up, 0.5);
      detector.update(up, 0.5);
      expect(detector.triggered, isTrue);
    });

    test('does not trigger on a push-up pose', () {
      final detector = HighFiveDetector();
      detector.update(plankPose(elbowAngle: 165), 0.5);
      detector.update(plankPose(elbowAngle: 165), 0.5);
      detector.update(plankPose(elbowAngle: 165), 0.5);
      detector.update(plankPose(elbowAngle: 90), 0.5);
      detector.update(plankPose(elbowAngle: 165), 0.5);
      expect(detector.triggered, isFalse);
    });

    test('fires once and re-arms after the debounce', () {
      final detector = HighFiveDetector();
      final up = highFivePose(handUp: true);
      final down = highFivePose(handUp: false);

      detector.update(up, 0.5);
      detector.update(up, 0.5);
      expect(detector.triggered, isTrue);
      detector.update(down, 0.5);
      expect(detector.triggered, isTrue);
      detector.update(down, 0.5);
      detector.update(down, 0.5);
      detector.update(down, 0.5);
      expect(detector.triggered, isFalse);
      detector.update(up, 0.5);
      detector.update(up, 0.5);
      expect(detector.triggered, isTrue);
    });

    test('reset clears the trigger', () {
      final detector = HighFiveDetector();
      final up = highFivePose(handUp: true);

      detector.update(up, 0.5);
      detector.update(up, 0.5);
      expect(detector.triggered, isTrue);
      detector.reset();
      expect(detector.triggered, isFalse);
      detector.update(up, 0.5);
      expect(detector.triggered, isFalse);
    });
  });
}

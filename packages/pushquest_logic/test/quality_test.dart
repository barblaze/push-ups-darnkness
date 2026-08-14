import 'package:pushquest_logic/pushquest_logic.dart';
import 'package:test/test.dart';

import 'pose_builder.dart';

void main() {
  group('analyzeBody', () {
    test('invisible pose is not visible', () {
      final analysis = analyzeBody(invisible());
      expect(analysis.bodyVisible, isFalse);
      expect(analysis.plank, isFalse);
      expect(analysis.dropRatio, 0);
    });

    test('needs shoulders, wrists and hips', () {
      final analysis = analyzeBody(frontPose(drop: 1.0, hipsVisible: false));
      expect(analysis.bodyVisible, isFalse);
    });

    test('front pose without ankles assumes a plank (no sag gate)', () {
      final analysis = analyzeBody(frontPose(drop: 1.0));
      expect(analysis.bodyVisible, isTrue);
      expect(analysis.sagRatio, 0);
      expect(analysis.plank, isTrue);
      expect(analysis.dropRatio, closeTo(1.0, 1e-9));
    });

    test('plank with hips in line is perfect', () {
      final analysis = analyzeBody(plankPose(elbowAngle: 180));
      expect(analysis.bodyVisible, isTrue);
      expect(analysis.sagRatio, closeTo(0, 1e-9));
      expect(analysis.plankRatio, 1.0);
      expect(analysis.plank, isTrue);
    });

    test('sagged hips map to a positive sagRatio and degrade straightness', () {
      final analysis = analyzeBody(plankPose(elbowAngle: 180, sag: 0.2));
      expect(analysis.sagRatio, closeTo(0.2, 1e-9));
      expect(analysis.plankRatio, closeTo(0.6522, 1e-3));
      expect(analysis.plank, isTrue);
    });

    test('deep sag drops the plank gate', () {
      final analysis = analyzeBody(plankPose(elbowAngle: 180, sag: 0.35));
      expect(analysis.sagRatio, closeTo(0.35, 1e-9));
      expect(analysis.plank, isFalse);
    });

    test('pike (hips up) maps to a negative sagRatio', () {
      final analysis = analyzeBody(plankPose(elbowAngle: 180, sag: -0.15));
      expect(analysis.sagRatio, closeTo(-0.15, 1e-9));
      // El lado negativo degrada más rápido: -0.15 → 0.75 de rectitud.
      expect(analysis.plankRatio, closeTo(0.75, 1e-9));
      expect(analysis.plank, isTrue);
    });

    test('front view keeps the depth signal and measures form at the same time',
        () {
      final up = analyzeBody(frontPlankPose(drop: 1, sag: 0.2));
      expect(up.bodyVisible, isTrue);
      expect(up.dropRatio, greaterThan(0.85));
      expect(up.sagRatio, closeTo(0.2, 1e-9));

      final down = analyzeBody(frontPlankPose(drop: 0, sag: -0.2));
      expect(down.bodyVisible, isTrue);
      expect(down.dropRatio, closeTo(0, 1e-9));
      expect(down.sagRatio, closeTo(-0.2, 1e-9));
    });
  });
}

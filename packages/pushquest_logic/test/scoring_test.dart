import 'package:pushquest_logic/pushquest_logic.dart';
import 'package:test/test.dart';

void main() {
  group('evaluateQuality', () {
    test('perfect depth and straightness', () {
      final q = evaluateQuality(
        minElbowAngle: 80,
        upAngle: 160,
        targetAngle: 80,
        minStraightness: 1.0,
      );
      expect(q.depthRatio, 1.0);
      expect(q.isGood, isTrue);
    });

    test('partial depth', () {
      final q = evaluateQuality(
        minElbowAngle: 95,
        upAngle: 160,
        targetAngle: 80,
        minStraightness: 1.0,
      );
      expect(q.depthRatio, closeTo(0.8125, 1e-9));
      expect(q.isGood, isTrue);
    });
  });

  group('straightnessFromSag', () {
    test('acceptable range is perfect', () {
      expect(straightnessFromSag(0), 1.0);
      expect(straightnessFromSag(0.12), 1.0);
      expect(straightnessFromSag(-0.10), 1.0);
    });

    test('degrades beyond tolerance', () {
      expect(straightnessFromSag(0.15), closeTo(0.8696, 1e-3));
      expect(straightnessFromSag(0.35), 0.0);
      expect(straightnessFromSag(-0.30), 0.0);
    });
  });

  group('RepScoring', () {
    test('perfect rep base points', () {
      const q = Quality(depthRatio: 1.0, straightness: 1.0, isGood: true);
      expect(RepScoring.points(quality: q, combo: 1), 10);
    });

    test('points scale with depth and straightness', () {
      const perfect = Quality(depthRatio: 1.0, straightness: 1.0, isGood: true);
      const shallow = Quality(depthRatio: 0.5, straightness: 1.0, isGood: false);
      expect(RepScoring.points(quality: shallow, combo: 1), lessThan(RepScoring.points(quality: perfect, combo: 1)));
    });

    test('combo multiplier caps at 2x', () {
      const q = Quality(depthRatio: 1.0, straightness: 1.0, isGood: true);
      expect(RepScoring.points(quality: q, combo: 1), 10);
      expect(RepScoring.points(quality: q, combo: 6), 15);
      expect(RepScoring.points(quality: q, combo: 11), 20);
      expect(RepScoring.points(quality: q, combo: 30), 20);
    });

    test('mission bonus only when completed', () {
      expect(RepScoring.missionBonus(20, 19), 0);
      expect(RepScoring.missionBonus(20, 20), 50);
      expect(RepScoring.missionBonus(20, 25), 50);
    });
  });
}

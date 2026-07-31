import 'package:pushquest_logic/pushquest_logic.dart';
import 'package:test/test.dart';

void main() {
  group('angleAt', () {
    test('right angle', () {
      const a = Joint(0, 1);
      const b = Joint(0, 0);
      const c = Joint(1, 0);
      expect(angleAt(a, b, c), closeTo(90, 0.01));
    });

    test('straight angle', () {
      const a = Joint(0, 1);
      const b = Joint(0, 0);
      const c = Joint(0, -1);
      expect(angleAt(a, b, c), closeTo(180, 0.01));
    });

    test('45 degrees', () {
      const a = Joint(0, 1);
      const b = Joint(0, 0);
      const c = Joint(1, 1);
      expect(angleAt(a, b, c), closeTo(45, 0.01));
    });
  });

  group('distance', () {
    test('pythagorean triple', () {
      expect(distance(const Joint(0, 0), const Joint(3, 4)), closeTo(5, 1e-9));
    });
  });

  group('signedDistanceToLine', () {
    test('below line is positive with y-down coordinates', () {
      const a = Joint(0, 0);
      const b = Joint(1, 0);
      expect(signedDistanceToLine(const Joint(0.5, 1), a, b), closeTo(1, 1e-9));
      expect(signedDistanceToLine(const Joint(0.5, -1), a, b), closeTo(-1, 1e-9));
    });

    test('head on the right flips the sign', () {
      const a = Joint(1, 0);
      const b = Joint(0, 0);
      expect(signedDistanceToLine(const Joint(0.5, 1), a, b), closeTo(-1, 1e-9));
    });
  });
}

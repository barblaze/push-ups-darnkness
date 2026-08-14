import 'package:pushquest_logic/pushquest_logic.dart';
import 'package:test/test.dart';

PoseData nosePose(double noseY, {bool visible = true}) {
  final joints = List<Joint>.generate(33, (i) => const Joint(0, 0, 0));
  joints[0] = Joint(0.3, noseY, visible ? 1.0 : 0.0);
  return PoseData(joints);
}

void main() {
  group('HeadCalibrator', () {
    test('mapea 0 = cabeza arriba y 1 = cabeza abajo tras calibrar', () {
      final cal = HeadCalibrator();
      expect(cal.calibrated, isFalse);
      cal.sample(nosePose(0.2));
      cal.sample(nosePose(0.8));
      expect(cal.calibrated, isTrue);
      expect(cal.headDepth(nosePose(0.2)), closeTo(0.0, 1e-9));
      expect(cal.headDepth(nosePose(0.8)), closeTo(1.0, 1e-9));
      expect(cal.headDepth(nosePose(0.5)), closeTo(0.5, 1e-9));
    });

    test('sin calibrar usa el rango fijo por defecto', () {
      final cal = HeadCalibrator();
      expect(cal.calibrated, isFalse);
      expect(cal.headDepth(nosePose(0.15)), closeTo(0.0, 1e-9));
      expect(cal.headDepth(nosePose(0.85)), closeTo(1.0, 1e-9));
    });

    test('un rango muestreado demasiado pequeño cae al rango fijo', () {
      final cal = HeadCalibrator();
      cal.sample(nosePose(0.45));
      cal.sample(nosePose(0.46));
      expect(cal.calibrated, isFalse);
      expect(cal.headDepth(nosePose(0.15)), closeTo(0.0, 1e-9));
      expect(cal.headDepth(nosePose(0.85)), closeTo(1.0, 1e-9));
    });

    test('faceVisible según la visibilidad de la nariz', () {
      final cal = HeadCalibrator();
      expect(cal.faceVisible(nosePose(0.5)), isTrue);
      expect(cal.faceVisible(nosePose(0.5, visible: false)), isFalse);
    });

    test('headDepth devuelve 0.5 si la nariz no es visible', () {
      final cal = HeadCalibrator();
      expect(cal.headDepth(nosePose(0.5, visible: false)), closeTo(0.5, 1e-9));
    });

    test('reset limpia la calibración', () {
      final cal = HeadCalibrator();
      cal.sample(nosePose(0.2));
      cal.sample(nosePose(0.8));
      expect(cal.calibrated, isTrue);
      cal.reset();
      expect(cal.calibrated, isFalse);
    });

    test('ignora frames con la cara no visible al muestrear', () {
      final cal = HeadCalibrator();
      cal.sample(nosePose(0.9, visible: false));
      expect(cal.calibrated, isFalse);
      // Sin rango calibrado usa el mapeo fijo (0.9 queda fuera, clamp a 1.0).
      expect(cal.headDepth(nosePose(0.9)), closeTo(1.0, 1e-9));
    });
  });
}

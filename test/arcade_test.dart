import 'package:flutter_test/flutter_test.dart';
import 'package:pushquest/game/arcade.dart';

void main() {
  ArcadeGame game({
    ArcadeConfig? config,
  }) =>
      ArcadeGame(config: config ?? const ArcadeConfig(firstSpawnDelay: 100));

  group('ArcadeGame control', () {
    test('altitude follows the target smoothly', () {
      final g = game();
      expect(g.altitude, closeTo(0.5, 1e-9));

      for (var i = 0; i < 40; i++) {
        g.update(0.05, targetAltitude: 0.8, bodyVisible: true);
      }
      expect(g.altitude, closeTo(0.8, 0.02));

      for (var i = 0; i < 40; i++) {
        g.update(0.05, targetAltitude: 0.2, bodyVisible: true);
      }
      expect(g.altitude, closeTo(0.2, 0.02));
    });

    test('holds its last target when body is not visible', () {
      final g = game();
      for (var i = 0; i < 40; i++) {
        g.update(0.05, targetAltitude: 0.8, bodyVisible: true);
      }
      final before = g.altitude;
      for (var i = 0; i < 40; i++) {
        g.update(0.05, targetAltitude: 0.1, bodyVisible: false);
      }
      expect(g.altitude, closeTo(0.8, 0.02));
      expect((g.altitude - before).abs(), lessThan(0.01));
    });

    test('target maps depth so that up is high and down is low', () {
      final g = game();
      expect(g.targetForDepth(0.0), closeTo(0.10, 0.01));
      expect(g.targetForDepth(1.0), closeTo(0.90, 0.01));
      expect(g.targetForDepth(0.5), lessThan(g.targetForDepth(1.0)));
      expect(g.targetForDepth(0.5), greaterThan(g.targetForDepth(0.0)));
    });

    test('extremos con zona muerta: pequeño movimiento no mueve el pájaro',
        () {
      final g = game();
      expect(g.targetForDepth(0.05), closeTo(0.10, 0.01));
      expect(g.targetForDepth(0.95), closeTo(0.90, 0.01));
      expect(g.targetForDepth(0.12), closeTo(0.10, 0.01));
      expect(g.targetForDepth(0.88), closeTo(0.90, 0.01));
    });

    test('altitude stays within the playable band', () {
      final g = game();
      for (var i = 0; i < 100; i++) {
        g.update(0.05, targetAltitude: 0.0, bodyVisible: true);
        expect(g.altitude, greaterThanOrEqualTo(0.05));
      }
      for (var i = 0; i < 100; i++) {
        g.update(0.05, targetAltitude: 1.0, bodyVisible: true);
        expect(g.altitude, lessThanOrEqualTo(0.95));
      }
    });
  });

  group('ArcadeGame sensitivity', () {
    test('sensitivity clamps to 0..100 and exposes smoothing', () {
      final g = game();
      expect(g.sensitivity, 50);
      expect(g.controlSmoothing, closeTo(6.0, 1e-9));

      g.setSensitivity(0);
      expect(g.sensitivity, 0);
      expect(g.controlSmoothing, closeTo(4.0, 1e-9));

      g.setSensitivity(100);
      expect(g.sensitivity, 100);
      expect(g.controlSmoothing, closeTo(8.0, 1e-9));

      g.setSensitivity(150);
      expect(g.sensitivity, 100);

      g.setSensitivity(-10);
      expect(g.sensitivity, 0);
    });

    test('lower sensitivity means less movement for the same depth', () {
      final low = game()..setSensitivity(0);
      final normal = game()..setSensitivity(50);
      final high = game()..setSensitivity(100);

      // Brazos extendidos (0) siempre van arriba.
      expect(high.targetForDepth(0.0), closeTo(0.10, 0.01));
      expect(low.targetForDepth(0.0), greaterThan(high.targetForDepth(0.0)));
      expect(low.targetForDepth(0.0), closeTo(0.222, 0.03));

      // Flexión completa (1) siempre va abajo.
      expect(normal.targetForDepth(1.0), closeTo(0.90, 0.01));
      expect(low.targetForDepth(1.0), closeTo(0.778, 0.03));

      // Recorrido total menor con sensibilidad baja.
      final lowRange =
          low.targetForDepth(1.0) - low.targetForDepth(0.0);
      final normalRange =
          normal.targetForDepth(1.0) - normal.targetForDepth(0.0);
      expect(lowRange, lessThan(normalRange));
    });

    test('low sensitivity is smoother (slower follow)', () {
      final low = game()..setSensitivity(0);
      final high = game()..setSensitivity(100);
      for (var i = 0; i < 5; i++) {
        low.update(0.05, targetAltitude: 0.8, bodyVisible: true);
        high.update(0.05, targetAltitude: 0.8, bodyVisible: true);
      }
      expect(high.altitude, closeTo(0.8, 0.1));
      expect(high.altitude, greaterThan(low.altitude));
    });
  });

  group('ArcadeGame control input', () {
    test('feedDepth filtra el ruido de la pose', () {
      final g = game();
      g.feedDepth(1.0);
      g.feedDepth(1.0);
      g.feedDepth(1.0);
      g.feedDepth(1.0);
      g.feedDepth(1.0);
      g.feedDepth(1.0);
      g.feedDepth(1.0);
      expect(g.filteredDepth, greaterThan(0.95));

      // Un frame ruidoso no debe desplazar apenas el control.
      final before = g.filteredDepth;
      g.feedDepth(0.2);
      expect((g.filteredDepth - before).abs(), lessThan(0.4));
    });

    test('deadband ignora cambios mínimos', () {
      final g = game();
      g.feedDepth(0.5);
      final before = g.filteredDepth;
      g.feedDepth(0.51);
      expect(g.filteredDepth, before);
    });

    test('targetAltitude refleja la profundidad filtrada', () {
      final g = game();
      for (var i = 0; i < 20; i++) {
        g.feedDepth(0.0);
      }
      expect(g.filteredDepth, lessThan(0.05));
      expect(g.targetAltitude, closeTo(0.10, 0.02));
    });

    test('mapea los extremos del movimiento en vivo', () {
      final g = game();
      for (var i = 0; i < 10; i++) {
        g.feedDepth(0.1);
      }
      expect(g.filteredDepth, lessThan(0.2));
      expect(g.targetAltitude, lessThan(0.4));

      for (var i = 0; i < 10; i++) {
        g.feedDepth(0.9);
      }
      expect(g.filteredDepth, greaterThan(0.8));
      expect(g.targetAltitude, greaterThan(0.6));
    });

    test('rango degenerado (apenas se mueve) usa el rango completo', () {
      final g = game();
      for (var i = 0; i < 25; i++) {
        g.feedDepth(0.55);
      }
      expect(g.filteredDepth, closeTo(0.55, 0.05));
      expect(g.targetAltitude, closeTo(0.5, 0.1));
    });

    test('se adapta al nuevo rango sin reiniciar', () {
      final g = game();
      for (var i = 0; i < 10; i++) {
        g.feedDepth(0.2);
      }
      final shallow = g.filteredDepth;
      // El jugador baja su rango y la normalización lo sigue en vivo.
      for (var i = 0; i < 10; i++) {
        g.feedDepth(0.6);
      }
      expect(g.filteredDepth, greaterThan(shallow));
      expect(g.filteredDepth, greaterThan(0.5));
    });
  });

  group('ArcadeGame gaps', () {
    ArcadeGame fastGame() => ArcadeGame(
          config: const ArcadeConfig(
            scrollSpeed: 0.5,
            spacing: 0.5,
            firstSpawnDelay: 0,
          ),
        );

    test('first obstacles are wider (warm-up), then gaps tighten', () {
      final g = fastGame();
      final gaps = <double>[];
      for (var i = 0; i < 8; i++) {
        g.update(1.0, targetAltitude: 0.5, bodyVisible: true);
        gaps.add(g.obstacles.last.gapHalf);
      }
      // Primeros 3: calentamiento (+15%).
      expect(gaps[0], closeTo(0.13 * 1.15, 1e-6));
      expect(gaps[1], closeTo(0.13 * 1.15, 1e-6));
      expect(gaps[2], closeTo(0.13 * 1.15, 1e-6));
      // A partir del 4º empieza la rampa de dificultad.
      expect(gaps[3], lessThan(gaps[2]));
      for (var i = 3; i < gaps.length - 1; i++) {
        expect(gaps[i + 1], lessThanOrEqualTo(gaps[i]));
      }
    });

    test('gap shrinks up to 30% once score is high', () {
      final g = fastGame();
      for (var i = 0; i < 6; i++) {
        g.update(1.0, targetAltitude: 0.5, bodyVisible: true);
      }
      g.score = 100;
      g.update(1.0, targetAltitude: 0.5, bodyVisible: true);
      expect(g.obstacles.last.gapHalf, closeTo(0.13 * 0.7, 1e-6));
    });
  });

  group('ArcadeGame obstacles', () {
    test('spawns obstacles after the first spawn delay', () {
      final g = ArcadeGame(
        config: const ArcadeConfig(
          scrollSpeed: 0.5,
          spacing: 0.5,
          firstSpawnDelay: 0,
        ),
      );
      expect(g.obstacles, isEmpty);
      g.update(1.0, targetAltitude: 0.5, bodyVisible: true);
      expect(g.obstacles, hasLength(1));
      expect(g.obstacles.first.x, closeTo(1.05, 1e-9));
    });

    test('spacing keeps distance between obstacles', () {
      final g = ArcadeGame(
        config: const ArcadeConfig(
          scrollSpeed: 0.5,
          spacing: 0.5,
          firstSpawnDelay: 0,
        ),
      );
      g.update(1.0, targetAltitude: 0.5, bodyVisible: true);
      g.update(1.0, targetAltitude: 0.5, bodyVisible: true);
      expect(g.obstacles, hasLength(2));
      final dx = (g.obstacles[0].x - g.obstacles[1].x).abs();
      expect(dx, closeTo(0.5, 0.02));
    });

    test('gap center avoids impossible jumps between obstacles', () {
      final g = ArcadeGame(
        config: const ArcadeConfig(
          scrollSpeed: 0.5,
          spacing: 0.5,
          firstSpawnDelay: 0,
        ),
      );
      double? previous;
      for (var i = 0; i < 20; i++) {
        g.update(1.0, targetAltitude: 0.5, bodyVisible: true);
        final last = g.obstacles.last.gapCenter;
        if (previous != null) {
          expect((last - previous).abs(), lessThanOrEqualTo(0.31));
        }
        previous = last;
      }
    });

    test('scores exactly once per passed obstacle', () {
      final g = game();
      g.obstacles.add(
        ArcadeObstacle(x: 0.3, gapCenter: 0.5, gapHalf: 0.13),
      );
      var events = <ArcadeEvent>[];
      for (var i = 0; i < 30; i++) {
        events.add(g.update(0.05, targetAltitude: 0.5, bodyVisible: true));
      }
      expect(events, contains(ArcadeEvent.passed));
      expect(g.score, 1);
      for (var i = 0; i < 30; i++) {
        g.update(0.05, targetAltitude: 0.5, bodyVisible: true);
      }
      expect(g.score, 1);
    });
  });

  group('ArcadeGame collisions', () {
    test('a hit outside the gap costs a life and grants invulnerability', () {
      final g = game();
      g.altitude = 0.9;
      g.obstacles.add(
        ArcadeObstacle(x: 0.3, gapCenter: 0.5, gapHalf: 0.13),
      );
      final event = g.update(0.01, targetAltitude: 0.9, bodyVisible: true);
      expect(event, ArcadeEvent.hit);
      expect(g.lives, 2);
      expect(g.invulnerable, isTrue);
    });

    test('no life lost while inside the gap', () {
      final g = game();
      g.altitude = 0.5;
      g.obstacles.add(
        ArcadeObstacle(x: 0.3, gapCenter: 0.5, gapHalf: 0.13),
      );
      final event = g.update(0.01, targetAltitude: 0.5, bodyVisible: true);
      expect(event, ArcadeEvent.none);
      expect(g.lives, 3);
    });

    test('invulnerability window prevents repeated hits', () {
      final g = game();
      g.altitude = 0.9;
      g.obstacles.add(
        ArcadeObstacle(x: 0.3, gapCenter: 0.5, gapHalf: 0.13),
      );
      expect(g.update(0.01, targetAltitude: 0.9, bodyVisible: true),
          ArcadeEvent.hit);
      expect(g.lives, 2);

      for (var i = 0; i < 10; i++) {
        g.obstacles.add(
          ArcadeObstacle(x: 0.3, gapCenter: 0.5, gapHalf: 0.13),
        );
        g.update(0.05, targetAltitude: 0.9, bodyVisible: true);
      }
      expect(g.lives, 2);

      for (var i = 0; i < 30; i++) {
        g.update(0.05, targetAltitude: 0.9, bodyVisible: true);
      }
      expect(g.invulnerable, isFalse);
      g.obstacles.add(
        ArcadeObstacle(x: 0.3, gapCenter: 0.5, gapHalf: 0.13),
      );
      expect(g.update(0.01, targetAltitude: 0.9, bodyVisible: true),
          ArcadeEvent.hit);
      expect(g.lives, 1);
    });

    test('game over at zero lives', () {
      final g = game();
      g.altitude = 0.9;
      for (var i = 0; i < 3; i++) {
        if (g.invulnerable) {
          for (var j = 0; j < 30; j++) {
            g.update(0.05, targetAltitude: 0.9, bodyVisible: true);
          }
        }
        g.obstacles.add(
          ArcadeObstacle(x: 0.3, gapCenter: 0.5, gapHalf: 0.13),
        );
        g.update(0.01, targetAltitude: 0.9, bodyVisible: true);
      }
      expect(g.lives, 0);
      expect(g.gameOver, isTrue);
      final event = g.update(0.01, targetAltitude: 0.9, bodyVisible: true);
      expect(event, ArcadeEvent.none);
    });

    test('speed ramps with score and caps at max', () {
      final g = ArcadeGame(
        config: const ArcadeConfig(
          scrollSpeed: 0.1,
          speedRamp: 0.05,
          maxSpeed: 0.4,
        ),
      );
      final base = g.speed;
      for (var i = 0; i < 20; i++) {
        g.obstacles.add(
          ArcadeObstacle(x: 0.3 - i * 0.01, gapCenter: 0.5, gapHalf: 0.2),
        );
        g.update(0.01, targetAltitude: 0.5, bodyVisible: true);
      }
      expect(g.score, greaterThan(0));
      expect(g.speed, greaterThan(base));
      expect(g.speed, lessThanOrEqualTo(0.4));
    });
  });

  group('ArcadeGame animacion', () {
    test('birdVelocity refleja la dirección de movimiento', () {
      final g = game();
      for (var i = 0; i < 20; i++) {
        g.update(0.05, targetAltitude: 0.85, bodyVisible: true);
      }
      expect(g.birdVelocity, greaterThan(0));

      for (var i = 0; i < 40; i++) {
        g.update(0.05, targetAltitude: 0.15, bodyVisible: true);
      }
      expect(g.birdVelocity, lessThan(0));
    });

    test('lastPassAt se marca al superar un pilar', () {
      final g = game();
      g.obstacles.add(
        ArcadeObstacle(x: 0.3, gapCenter: 0.5, gapHalf: 0.13),
      );
      var passed = false;
      for (var i = 0; i < 40 && !passed; i++) {
        final e = g.update(0.05, targetAltitude: 0.5, bodyVisible: true);
        if (e == ArcadeEvent.passed) passed = true;
      }
      expect(passed, isTrue);
      expect(g.lastPassAt, greaterThan(0));
    });

    test('hitAt y gameOverAt se marcan al morir', () {
      final g = game();
      g.altitude = 0.9;
      for (var i = 0; i < 3; i++) {
        if (g.invulnerable) {
          for (var j = 0; j < 40; j++) {
            g.update(0.05, targetAltitude: 0.9, bodyVisible: true);
          }
        }
        g.obstacles.add(
          ArcadeObstacle(x: 0.3, gapCenter: 0.5, gapHalf: 0.13),
        );
        g.update(0.01, targetAltitude: 0.9, bodyVisible: true);
      }
      expect(g.gameOver, isTrue);
      expect(g.hitAt, greaterThan(0));
      expect(g.gameOverAt, greaterThan(0));
    });

    test('tick avanza el reloj visual tras el game over', () {
      final g = game();
      g.altitude = 0.9;
      for (var i = 0; i < 3; i++) {
        if (g.invulnerable) {
          for (var j = 0; j < 40; j++) {
            g.update(0.05, targetAltitude: 0.9, bodyVisible: true);
          }
        }
        g.obstacles.add(
          ArcadeObstacle(x: 0.3, gapCenter: 0.5, gapHalf: 0.13),
        );
        g.update(0.01, targetAltitude: 0.9, bodyVisible: true);
      }
      expect(g.gameOver, isTrue);
      final frozen = g.elapsed;
      g.tick(0.1);
      expect(g.elapsed, closeTo(frozen + 0.1, 1e-9));
    });
  });
}

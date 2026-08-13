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
      expect(g.targetForDepth(0.0), closeTo(0.06, 0.01));
      expect(g.targetForDepth(1.0), closeTo(0.94, 0.01));
      expect(g.targetForDepth(0.5), lessThan(g.targetForDepth(1.0)));
      expect(g.targetForDepth(0.5), greaterThan(g.targetForDepth(0.0)));
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
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pushquest/game/arcade.dart';
import 'package:pushquest/widgets/arcade_painter.dart';

void main() {
  Widget wrap(
    ArcadeGame game, {
    int best = 5,
    bool showDepthGauge = false,
    double depthRatio = 0.5,
  }) {
    return MaterialApp(
      home: SizedBox(
        width: 320,
        height: 520,
        child: CustomPaint(
          painter: ArcadePainter(
            game: game,
            characterColor: const Color(0xFFFF6B35),
            bestScore: best,
            showDepthGauge: showDepthGauge,
            depthRatio: depthRatio,
          ),
        ),
      ),
    );
  }

  testWidgets('painter renders durante el juego sin errores', (tester) async {
    final game = ArcadeGame(
      config: const ArcadeConfig(firstSpawnDelay: 100),
    );
    for (var i = 0; i < 20; i++) {
      game.update(0.05, targetAltitude: 0.3, bodyVisible: true);
    }
    await tester.pumpWidget(wrap(game));
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.takeException(), isNull);
  });

  testWidgets('painter renderiza el estado de game over con muerte',
      (tester) async {
    final game = ArcadeGame(
      config: const ArcadeConfig(firstSpawnDelay: 100),
    );
    game.altitude = 0.9;
    for (var i = 0; i < 3; i++) {
      if (game.invulnerable) {
        for (var j = 0; j < 40; j++) {
          game.update(0.05, targetAltitude: 0.9, bodyVisible: true);
        }
      }
      game.obstacles.add(
        ArcadeObstacle(x: 0.3, gapCenter: 0.5, gapHalf: 0.13),
      );
      game.update(0.01, targetAltitude: 0.9, bodyVisible: true);
    }
    expect(game.gameOver, isTrue);
    for (var i = 0; i < 12; i++) {
      game.tick(0.1);
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('painter maneja nuevo récord sin excepciones', (tester) async {
    final game = ArcadeGame(
      config: const ArcadeConfig(firstSpawnDelay: 100),
    );
    game.score = 12;
    game.lastPassAt = 0;
    await tester.pumpWidget(wrap(game, best: 5));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });

  testWidgets('painter dibuja el gauge de profundidad en countdown',
      (tester) async {
    final game = ArcadeGame(
      config: const ArcadeConfig(firstSpawnDelay: 100),
    );
    await tester.pumpWidget(
      wrap(game, showDepthGauge: true, depthRatio: 0.7),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  });
}

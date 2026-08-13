import 'package:flutter/material.dart';

import '../game/arcade.dart';
import '../theme/app_theme.dart';

class ArcadePainter extends CustomPainter {
  ArcadePainter({required this.game, required this.emoji});

  final ArcadeGame game;
  final String emoji;

  static const _groundFraction = 0.08;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    _drawClouds(canvas, w, h);
    _drawGround(canvas, w, h);
    _drawObstacles(canvas, w, h);
    _drawBird(canvas, w, h);

    final scorePaint = TextPainter(
      text: TextSpan(
        text: '${game.score}',
        style: const TextStyle(
          fontSize: 40,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          shadows: [Shadow(color: Colors.black87, blurRadius: 10)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    scorePaint.paint(
      canvas,
      Offset((w - scorePaint.width) / 2, h * 0.06),
    );
  }

  void _drawGround(Canvas canvas, double w, double h) {
    final groundTop = h * (1 - _groundFraction);
    final paint = Paint()..color = const Color(0xFF1F2630);
    canvas.drawRect(Rect.fromLTWH(0, groundTop, w, h - groundTop), paint);

    final linePaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.7)
      ..strokeWidth = 3;
    final phase = (game.elapsed * game.speed * w * 3) % 40;
    for (var x = -phase; x < w + 40; x += 40) {
      canvas.drawLine(
        Offset(x, groundTop + 14),
        Offset(x + 18, groundTop + 14),
        linePaint,
      );
    }
  }

  void _drawClouds(Canvas canvas, double w, double h) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.18);
    const cloudY = [0.18, 0.32, 0.45];
    for (var i = 0; i < cloudY.length; i++) {
      final speed = 0.5 + i * 0.2;
      final offset = (game.elapsed * game.speed * speed * w) % (w + 160);
      final x = w - offset;
      final y = h * cloudY[i];
      canvas.drawOval(Rect.fromCenter(center: Offset(x, y), width: 90, height: 26), paint);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x - 26, y + 8), width: 60, height: 20),
        paint,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x + 30, y + 6), width: 54, height: 18),
        paint,
      );
    }
  }

  void _drawObstacles(Canvas canvas, double w, double h) {
    final pillarW = w * 0.09;
    for (final obstacle in game.obstacles) {
      final cx = obstacle.x * w;
      final gapTop = (obstacle.gapCenter - obstacle.gapHalf) * h;
      final gapBottom = (obstacle.gapCenter + obstacle.gapHalf) * h;
      final groundTop = h * (1 - _groundFraction);

      final fill = Paint()..color = AppColors.primary;
      final edge = Paint()
        ..color = AppColors.primary.withValues(alpha: 0.4)
        ..strokeWidth = 4;

      final top = Rect.fromLTWH(cx - pillarW / 2, 0, pillarW, gapTop);
      canvas.drawRRect(
        RRect.fromRectAndCorners(top, bottomRight: const Radius.circular(12)),
        fill,
      );
      canvas.drawRRect(
        RRect.fromRectAndCorners(top, bottomRight: const Radius.circular(12)),
        edge,
      );

      final bottom = Rect.fromLTWH(
        cx - pillarW / 2,
        gapBottom,
        pillarW,
        groundTop - gapBottom,
      );
      canvas.drawRRect(
        RRect.fromRectAndCorners(bottom, topRight: const Radius.circular(12)),
        fill,
      );
      canvas.drawRRect(
        RRect.fromRectAndCorners(bottom, topRight: const Radius.circular(12)),
        edge,
      );
    }
  }

  void _drawBird(Canvas canvas, double w, double h) {
    if (game.invulnerable && (game.elapsed * 6).floor().isEven) return;
    final center = Offset(game.birdX * w, game.altitude * h);
    final radius = game.birdRadius * h;

    final shadow = Paint()..color = Colors.black.withValues(alpha: 0.3);
    canvas.drawCircle(center + const Offset(2, 3), radius, shadow);

    final painter = TextPainter(
      text: TextSpan(
        text: emoji,
        style: TextStyle(fontSize: radius * 2.1),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant ArcadePainter oldDelegate) => true;
}

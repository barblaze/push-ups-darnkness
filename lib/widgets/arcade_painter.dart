import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../game/arcade.dart';
import '../theme/app_theme.dart';

class ArcadePainter extends CustomPainter {
  ArcadePainter({
    required this.game,
    required this.characterColor,
    required this.bestScore,
    this.showDepthGauge = false,
  }) : super(repaint: game);

  final ArcadeGame game;

  /// Color del atuendo del personaje (heredado de la etapa de avatar).
  final Color characterColor;

  /// Mejor puntaje guardado, para el aviso de nuevo récord.
  final int bestScore;

  /// Dibuja el medidor de profundidad (calibración durante el countdown).
  final bool showDepthGauge;

  static const _groundFraction = 0.08;

  static final _starPositions = _buildStars();

  static List<_Star> _buildStars() {
    final rand = math.Random(7);
    return List.generate(
      26,
      (_) => _Star(
        x: rand.nextDouble(),
        y: rand.nextDouble() * 0.42,
        r: 0.8 + rand.nextDouble() * 1.4,
        tw: 1 + rand.nextDouble() * 3,
      ),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.save();
    _applyShake(canvas, w, h);

    _drawSky(canvas, w, h);
    _drawStars(canvas, w, h);
    _drawSun(canvas, w, h);
    _drawHills(canvas, w, h);
    _drawClouds(canvas, w, h);
    _drawGround(canvas, w, h);
    _drawObstacles(canvas, w, h);
    _drawSpeedLines(canvas, w, h);
    _drawCharacter(canvas, w, h);
    canvas.restore();

    _drawScoreAndHud(canvas, w, h);
    if (showDepthGauge) _drawDepthGauge(canvas, w, h);
    _drawHitFlash(canvas, w, h);
  }

  void _drawDepthGauge(Canvas canvas, double w, double h) {
    const topRatio = 0.06;
    const bottomRatio = 0.94;
    final trackX = w - 26.0;
    final topY = h * 0.2;
    final bottomY = h * 0.78;
    final trackH = bottomY - topY;
    final trackRect = Rect.fromLTWH(trackX, topY, 9, trackH);

    canvas.drawRRect(
      RRect.fromRectAndRadius(trackRect, const Radius.circular(4.5)),
      Paint()..color = const Color(0x66000000),
    );

    // Objetivo del pájaro según la profundidad actual (mapeo directo 1:1).
    final target = game.targetForDepth(game.filteredDepth).clamp(0.0, 1.0);
    final dotY = topY + (target / (bottomRatio - topRatio)) * trackH;
    canvas.drawCircle(
      Offset(trackX + 4.5, dotY),
      6,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset(trackX + 4.5, dotY),
      4,
      Paint()..color = characterColor,
    );

    final label = TextPainter(
      text: TextSpan(
        text: 'ARRIBA',
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: Colors.white70,
          shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset(trackX - 2, topY - 14));

    final label2 = TextPainter(
      text: TextSpan(
        text: 'ABAJO',
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: Colors.white70,
          shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label2.paint(canvas, Offset(trackX - 2, bottomY + 4));
  }

  void _applyShake(Canvas canvas, double w, double h) {
    final since = game.elapsed - game.hitAt;
    if (game.gameOver || since < 0 || since > 0.4) return;
    final amp = (1 - since / 0.4) * 7;
    final phase = game.elapsed * 55;
    canvas.translate(
      math.sin(phase) * amp,
      math.cos(phase * 1.3) * amp * 0.7,
    );
  }

  void _drawSky(Canvas canvas, double w, double h) {
    // El tono del cielo se desplaza sutilmente con el progreso.
    final shift = (game.elapsed * game.speed * 12) % 24;
    final top = Color.lerp(
        const Color(0xFF131A33), const Color(0xFF2A1A45), shift / 24)!;
    final mid = Color.lerp(
        const Color(0xFF4A2460), const Color(0xFF3D3D6E), shift / 24)!;
    final bottom = Color.lerp(
        const Color(0xFF7A2F52), const Color(0xFF5C2A6B), shift / 24)!;
    final rect = Rect.fromLTWH(0, 0, w, h);
    final shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [top, mid, bottom],
    ).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = shader);
  }

  void _drawStars(Canvas canvas, double w, double h) {
    final paint = Paint();
    for (final star in _starPositions) {
      final alpha =
          0.25 + 0.25 * math.sin(game.elapsed * star.tw + star.x * 40);
      paint.color = Colors.white.withValues(alpha: alpha.clamp(0.05, 0.5));
      canvas.drawCircle(Offset(star.x * w, star.y * h), star.r, paint);
    }
  }

  void _drawSun(Canvas canvas, double w, double h) {
    final center = Offset(w * 0.78, h * 0.2);
    final radius = w * 0.09;
    final rect = Rect.fromCircle(center: center, radius: radius * 2);
    final shader = RadialGradient(
      colors: [
        AppColors.primary.withValues(alpha: 0.5),
        AppColors.primary.withValues(alpha: 0.0),
      ],
    ).createShader(rect);
    canvas.drawCircle(center, radius * 2, Paint()..shader = shader);
    canvas.drawCircle(center, radius, Paint()..color = const Color(0xFFFFC46B));
  }

  void _drawHills(Canvas canvas, double w, double h) {
    final groundTop = h * (1 - _groundFraction);
    for (var layer = 0; layer < 2; layer++) {
      final parallax = 0.12 + layer * 0.16;
      final peak = h * (0.16 + layer * 0.14);
      final offset = (game.elapsed * game.speed * parallax * w) % (w * 2);
      final path = Path()..moveTo(-offset, groundTop);
      const step = 70.0;
      for (var x = -offset; x <= w * 2; x += step) {
        final rel = (x + offset) / w;
        final y = groundTop -
            peak * (0.55 + 0.45 * math.sin(rel * 6.5 + layer * 2.1));
        path.lineTo(x, y);
      }
      path.lineTo(w * 2, groundTop);
      path.close();
      canvas.drawPath(
        path,
        Paint()
          ..color =
              const Color(0xFF1C1440).withValues(alpha: 0.45 + layer * 0.2),
      );
    }
  }

  void _drawClouds(Canvas canvas, double w, double h) {
    const layers = [
      (y: 0.14, speed: 0.35, alpha: 0.10, scale: 1.3),
      (y: 0.24, speed: 0.6, alpha: 0.14, scale: 1.0),
      (y: 0.38, speed: 0.9, alpha: 0.18, scale: 0.75),
    ];
    for (final layer in layers) {
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: layer.alpha);
      final offset = (game.elapsed * game.speed * layer.speed * w) % (w + 200);
      for (var i = 0; i < 3; i++) {
        final x = w - offset + i * w * 0.62;
        if (x < -220 || x > w + 220) continue;
        _drawCloud(canvas, Offset(x, h * layer.y), 90 * layer.scale,
            26 * layer.scale, paint);
      }
    }
  }

  void _drawCloud(
      Canvas canvas, Offset c, double width, double height, Paint paint) {
    canvas.drawOval(
        Rect.fromCenter(center: c, width: width, height: height), paint);
    canvas.drawOval(
      Rect.fromCenter(
        center: c.translate(-width * 0.3, height * 0.35),
        width: width * 0.62,
        height: height * 0.75,
      ),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: c.translate(width * 0.32, height * 0.3),
        width: width * 0.6,
        height: height * 0.7,
      ),
      paint,
    );
  }

  void _drawGround(Canvas canvas, double w, double h) {
    final groundTop = h * (1 - _groundFraction);
    final groundHeight = h * _groundFraction;

    final fill = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [Color(0xFF232A38), Color(0xFF0E1116)],
      ).createShader(Rect.fromLTWH(0, groundTop, w, groundHeight));
    canvas.drawRect(Rect.fromLTWH(0, groundTop, w, groundHeight), fill);

    canvas.drawRect(
      Rect.fromLTWH(0, groundTop, w, h * 0.016),
      Paint()..color = AppColors.success.withValues(alpha: 0.55),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, groundTop + h * 0.016, w, h * 0.004),
      Paint()..color = const Color(0xFF1E4D33),
    );

    final tick = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final phase = (game.elapsed * game.speed * w) % 44;
    for (var x = -phase; x < w + 44; x += 44) {
      canvas.drawLine(
        Offset(x, groundTop + h * 0.032),
        Offset(x + 20, groundTop + h * 0.032),
        tick,
      );
    }
  }

  void _drawObstacles(Canvas canvas, double w, double h) {
    final pillarW = w * 0.09;
    final groundTop = h * (1 - _groundFraction);
    for (final obstacle in game.obstacles) {
      final cx = obstacle.x * w;
      final gapTop = (obstacle.gapCenter - obstacle.gapHalf) * h;
      final gapBottom = (obstacle.gapCenter + obstacle.gapHalf) * h;

      final fill = Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            const Color(0xFFB8431B),
            AppColors.primary,
            const Color(0xFFFF8A4D),
          ],
        ).createShader(Rect.fromLTWH(cx - pillarW / 2, 0, pillarW, h));
      final dark = Paint()..color = const Color(0xFF7A260F);

      final top = Rect.fromLTWH(cx - pillarW / 2, 0, pillarW, gapTop);
      final topRRect =
          RRect.fromRectAndCorners(top, bottomRight: const Radius.circular(12));
      canvas.drawRRect(topRRect, fill);
      canvas.drawRRect(
          topRRect,
          dark
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);

      final bottom = Rect.fromLTWH(
        cx - pillarW / 2,
        gapBottom,
        pillarW,
        groundTop - gapBottom,
      );
      final bottomRRect =
          RRect.fromRectAndCorners(bottom, topRight: const Radius.circular(12));
      canvas.drawRRect(bottomRRect, fill);
      canvas.drawRRect(
          bottomRRect,
          dark
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);

      // Banda de remate en el borde del hueco (más ancha y clara).
      final capPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [const Color(0xFFE8A16B), const Color(0xFFFFD9B0)],
        ).createShader(
            Rect.fromLTWH(cx - pillarW * 0.62, 0, pillarW * 1.24, h));
      final capH = pillarW * 0.42;
      final capTop = RRect.fromRectAndCorners(
        Rect.fromLTWH(cx - pillarW * 0.62, gapTop - capH, pillarW * 1.24, capH),
        bottomRight: const Radius.circular(10),
        bottomLeft: const Radius.circular(10),
      );
      final capBottom = RRect.fromRectAndCorners(
        Rect.fromLTWH(cx - pillarW * 0.62, gapBottom, pillarW * 1.24, capH),
        topRight: const Radius.circular(10),
        topLeft: const Radius.circular(10),
      );
      canvas.drawRRect(capTop, capPaint);
      canvas.drawRRect(capBottom, capPaint);

      // Guía tenue del hueco para apuntar.
      final guide = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, (obstacle.gapCenter) * h),
          width: pillarW * 1.5,
          height: (obstacle.gapHalf) * h * 2,
        ),
        const Radius.circular(10),
      );
      canvas.drawRRect(
        guide,
        Paint()
          ..color = AppColors.accent.withValues(alpha: 0.14)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
  }

  void _drawSpeedLines(Canvas canvas, double w, double h) {
    final range = game.speed - 0.22;
    final ratio = (range / 0.12).clamp(0.0, 1.0);
    if (ratio <= 0.1) return;
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18 * ratio)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final offset =
          (game.elapsed * game.speed * w * (1.2 + (i % 3) * 0.4)) % (w + 300);
      final x = w - offset;
      final y = h * (0.12 + ((i * 53) % 46) / 100);
      final len = 40 + (i % 3) * 24;
      canvas.drawLine(Offset(x, y), Offset(x + len, y), paint);
    }
  }

  void _drawCharacter(Canvas canvas, double w, double h) {
    if (game.invulnerable &&
        !game.gameOver &&
        (game.elapsed * 6).floor().isEven) {
      return;
    }
    final center = Offset(game.birdX * w, game.altitude * h);
    final r = game.birdRadius * h;

    _drawTrail(canvas, center, r);

    canvas.save();
    canvas.translate(center.dx, center.dy);

    var rotation = 0.0;
    var stretch = 0.0;
    if (game.gameOver) {
      // Animación de muerte: cae girando y se hunde.
      final t = (game.elapsed - game.gameOverAt).clamp(0.0, 1.4);
      rotation = t * math.pi * 2.6;
      canvas.translate(0, t * t * h * 0.55);
    } else {
      rotation = (game.birdVelocity * 3.5).clamp(-0.5, 0.5);
      stretch = (game.birdVelocity.abs() * 0.9).clamp(0.0, 0.18);
      final sinceHit = game.elapsed - game.hitAt;
      if (sinceHit >= 0 && sinceHit < 0.35) {
        canvas.translate(
          math.sin(game.elapsed * 60) * 3,
          math.cos(game.elapsed * 60) * 2,
        );
      }
    }
    canvas.rotate(rotation);
    canvas.scale(1 - stretch, 1 + stretch);

    _drawWings(canvas, r);
    _drawBody(canvas, r);
    canvas.restore();
  }

  void _drawTrail(Canvas canvas, Offset center, double r) {
    if (game.gameOver || game.birdVelocity.abs() < 0.4) return;
    for (var i = 1; i <= 4; i++) {
      final alpha = 0.18 * (1 - (i - 1) / 4);
      canvas.drawCircle(
        center.translate(-i * r * 0.42, -i * r * 0.18),
        r * (1 - i * 0.16),
        Paint()..color = characterColor.withValues(alpha: alpha),
      );
    }
  }

  void _drawWings(Canvas canvas, double r) {
    final flap =
        game.gameOver ? math.pi / 2 : math.sin(game.elapsed * 15) * 0.65;
    final wingPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: const [Color(0xFFFDF6EC), Color(0xFFD9CFC0)],
      ).createShader(Rect.fromLTWH(-r * 1.6, -r * 0.7, r * 3.2, r * 1.4));
    final edge = Paint()
      ..color = const Color(0xFF8F877B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final side in const [1.0, -1.0]) {
      canvas.save();
      canvas.translate(side * r * 0.55, -r * 0.1);
      canvas.rotate(side * -flap);
      final wing = RRect.fromRectAndCorners(
        Rect.fromLTWH(side * r * 0.1, -r * 0.3, side * r * 1.05, r * 0.6),
        bottomRight: Radius.circular(r * 0.5),
        topRight: Radius.circular(r * 0.2),
      );
      canvas.drawRRect(wing, wingPaint);
      canvas.drawRRect(wing, edge);
      canvas.restore();
    }
  }

  void _drawBody(Canvas canvas, double r) {
    final hurt = !game.gameOver &&
        game.elapsed - game.hitAt >= 0 &&
        game.elapsed - game.hitAt < 0.5;

    // Capa: capa/atuendo con el color del avatar.
    final suit = Paint()
      ..shader = RadialGradient(
        colors: [
          Color.lerp(characterColor, Colors.white, 0.25)!,
          characterColor
        ],
      ).createShader(Rect.fromCircle(center: Offset(0, 0), radius: r * 1.1));

    // Piernas.
    final legPaint = Paint()
      ..color = Color.lerp(characterColor, Colors.black, 0.35)!
      ..strokeWidth = r * 0.24
      ..strokeCap = StrokeCap.round;
    for (final side in const [-1.0, 1.0]) {
      canvas.drawLine(
        Offset(side * r * 0.18, r * 0.5),
        Offset(side * r * 0.26, r * 1.0),
        legPaint,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(side * r * 0.3, r * 1.05),
          width: r * 0.42,
          height: r * 0.2,
        ),
        legPaint,
      );
    }

    // Cuerpo.
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(0, -r * 0.05), width: r * 1.3, height: r * 1.35),
      suit,
    );

    // Cabello.
    final hair = Paint()
      ..color = Color.lerp(characterColor, Colors.black, 0.2)!;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(0, -r * 0.92), radius: r * 0.68),
      math.pi,
      math.pi,
      false,
      hair,
    );

    // Cabeza.
    final skin = Paint()..color = const Color(0xFFF2C48D);
    canvas.drawCircle(Offset(0, -r * 0.9), r * 0.62, skin);

    // Cara.
    if (game.gameOver) {
      _drawXEye(canvas, Offset(-r * 0.24, -r * 0.92), r * 0.14);
      _drawXEye(canvas, Offset(r * 0.24, -r * 0.92), r * 0.14);
      final mouth = Paint()
        ..color = const Color(0xFF5A3A2A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.09;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(0, -r * 0.62), radius: r * 0.2),
        math.pi * 0.15,
        math.pi * 0.7,
        false,
        mouth,
      );
    } else if (hurt) {
      // Ojos asustados.
      final white = Paint()..color = Colors.white;
      final pupil = Paint()..color = const Color(0xFF1F2630);
      for (final side in const [-1.0, 1.0]) {
        canvas.drawCircle(Offset(side * r * 0.24, -r * 0.9), r * 0.16, white);
        canvas.drawCircle(Offset(side * r * 0.24, -r * 0.9), r * 0.08, pupil);
      }
      final mouth = Paint()
        ..color = const Color(0xFF5A3A2A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.09;
      canvas.drawCircle(
          Offset(0, -r * 0.62), r * 0.16, mouth..style = PaintingStyle.stroke);
    } else {
      // Ojos normales con parpadeo.
      final blink = (game.elapsed % 3.4) < 0.14;
      final white = Paint()..color = Colors.white;
      final pupil = Paint()..color = const Color(0xFF1F2630);
      if (blink) {
        final line = Paint()
          ..color = const Color(0xFF1F2630)
          ..strokeWidth = r * 0.09
          ..strokeCap = StrokeCap.round;
        for (final side in const [-1.0, 1.0]) {
          canvas.drawLine(
            Offset(side * r * 0.24 - r * 0.1, -r * 0.9),
            Offset(side * r * 0.24 + r * 0.1, -r * 0.9),
            line,
          );
        }
      } else {
        for (final side in const [-1.0, 1.0]) {
          canvas.drawCircle(Offset(side * r * 0.24, -r * 0.9), r * 0.16, white);
          canvas.drawCircle(
              Offset(side * r * 0.24, -r * 0.88), r * 0.08, pupil);
        }
      }
      final smile = Paint()
        ..color = const Color(0xFF5A3A2A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.09
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(0, -r * 0.68), radius: r * 0.22),
        math.pi * 0.2,
        math.pi * 0.6,
        false,
        smile,
      );
    }

    _drawDeathFeathers(canvas, r);
  }

  void _drawXEye(Canvas canvas, Offset c, double s) {
    final p = Paint()
      ..color = const Color(0xFF1F2630)
      ..strokeWidth = s * 0.35
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c - Offset(s, s), c + Offset(s, s), p);
    canvas.drawLine(c - Offset(s, -s), c + Offset(s, -s), p);
  }

  void _drawDeathFeathers(Canvas canvas, double r) {
    if (!game.gameOver) return;
    final t = (game.elapsed - game.gameOverAt).clamp(0.0, 1.2);
    final paint = Paint();
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4 + i * 0.4;
      final speed = 0.7 + (i % 3) * 0.35;
      final x =
          math.cos(a) * (0.15 + t * 0.9) * r * 2.4 + math.sin(a * 2) * r * 0.4;
      final y =
          math.sin(a) * 0.15 * r * 2 + t * (speed) * r * 2.2 + t * t * r * 2;
      final alpha = (1 - t / 1.2).clamp(0.0, 1.0);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * 3 + i);
      paint.color = Colors.white.withValues(alpha: alpha * 0.9);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset.zero, width: r * 0.34, height: r * 0.16),
          paint);
      canvas.restore();
    }
  }

  void _drawScoreAndHud(Canvas canvas, double w, double h) {
    final passT = game.elapsed - game.lastPassAt;
    final pop = passT >= 0 && passT < 0.35
        ? 1 + 0.18 * math.sin(math.pi * passT / 0.35)
        : 1.0;

    final scorePaint = TextPainter(
      text: TextSpan(
        text: '${game.score}',
        style: TextStyle(
          fontSize: 40 * pop,
          fontWeight: FontWeight.w900,
          color: Colors.white,
          shadows: const [Shadow(color: Colors.black87, blurRadius: 10)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final scoreOffset = Offset((w - scorePaint.width) / 2, h * 0.06);
    scorePaint.paint(canvas, scoreOffset);

    // "+1" flotante al pasar un pilar.
    if (passT >= 0 && passT < 0.6 && !game.gameOver) {
      final rise = passT / 0.6;
      final plus = TextPainter(
        text: TextSpan(
          text: '+1',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: AppColors.accent,
            shadows: const [Shadow(color: Colors.black87, blurRadius: 6)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      plus.paint(
        canvas,
        Offset(
          (w - plus.width) / 2,
          scoreOffset.dy + 46 - rise * 34,
        ),
      );
    }

    // Aviso de nuevo récord en vivo.
    if (bestScore > 0 && game.score > bestScore && !game.gameOver) {
      final pulse = 0.6 + 0.4 * math.sin(game.elapsed * 7);
      final best = TextPainter(
        text: TextSpan(
          text: '¡NUEVO RÉCORD!',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
            color: AppColors.warning.withValues(alpha: pulse),
            shadows: const [Shadow(color: Colors.black87, blurRadius: 8)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      best.paint(canvas, Offset((w - best.width) / 2, scoreOffset.dy + 52));
    }
  }

  void _drawHitFlash(Canvas canvas, double w, double h) {
    if (game.gameOver) return;
    final since = game.elapsed - game.hitAt;
    if (since < 0 || since > 0.35) return;
    final alpha = (1 - since / 0.35) * 0.22;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = AppColors.danger.withValues(alpha: alpha),
    );
  }

  @override
  bool shouldRepaint(covariant ArcadePainter oldDelegate) => true;
}

class _Star {
  const _Star({
    required this.x,
    required this.y,
    required this.r,
    required this.tw,
  });

  final double x;
  final double y;
  final double r;
  final double tw;
}

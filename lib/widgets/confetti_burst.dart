import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Lluvia de confeti de una sola pasada, sin dependencias externas.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, this.duration = const Duration(milliseconds: 2600)});

  final Duration duration;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Particle> _particles;

  static const _palette = [
    Color(0xFFFF6B35),
    Color(0xFF22C1C3),
    Color(0xFF2ECC71),
    Color(0xFFF2C94C),
    Color(0xFFEB5757),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..forward();
    _particles = List.generate(
      90,
      (_) => _Particle(
        x: math.Random().nextDouble(),
        y0: -0.2 * math.Random().nextDouble(),
        speed: 0.9 + math.Random().nextDouble() * 0.7,
        w: 6 + math.Random().nextDouble() * 8,
        h: 10 + math.Random().nextDouble() * 10,
        spin: 6 + math.Random().nextDouble() * 12,
        phase: math.Random().nextDouble() * math.pi * 2,
        color: _palette[math.Random().nextInt(_palette.length)],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _ConfettiPainter(
            progress: _controller.value,
            particles: _particles,
          ),
        ),
      ),
    );
  }
}

class _Particle {
  const _Particle({
    required this.x,
    required this.y0,
    required this.speed,
    required this.w,
    required this.h,
    required this.spin,
    required this.phase,
    required this.color,
  });

  final double x;
  final double y0;
  final double speed;
  final double w;
  final double h;
  final double spin;
  final double phase;
  final Color color;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.progress, required this.particles});

  final double progress;
  final List<_Particle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final y = (p.y0 + progress * p.speed) * size.height;
      if (y > size.height + 30 || y < -30) continue;
      final wobble = math.sin(progress * 10 + p.phase) * 14;
      final x = (p.x + wobble / size.width) * size.width;
      final fade = progress < 0.85
          ? 1.0
          : (1 - (progress - 0.85) / 0.15).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = p.color.withValues(alpha: fade.clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(progress * p.spin + p.phase);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.w,
            height: p.h,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

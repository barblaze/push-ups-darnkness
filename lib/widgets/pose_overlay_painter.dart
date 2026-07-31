import 'package:flutter/material.dart';
import 'package:pushquest_logic/pushquest_logic.dart';

class PoseOverlayPainter extends CustomPainter {
  PoseOverlayPainter({
    required this.pose,
    this.mirror = false,
    this.color = Colors.greenAccent,
  });

  final PoseData pose;
  final bool mirror;
  final Color color;

  static const List<(int, int)> connections = [
    (7, 8),
    (8, 9),
    (9, 10),
    (0, 8),
    (0, 9),
    (11, 12),
    (11, 23),
    (12, 24),
    (23, 24),
    (11, 13),
    (13, 15),
    (12, 14),
    (14, 16),
    (23, 25),
    (25, 27),
    (24, 26),
    (26, 28),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (pose.joints.length != PoseData.count) return;

    Offset point(int i) {
      final j = pose[i];
      final x = mirror ? size.width - j.x * size.width : j.x * size.width;
      return Offset(x, j.y * size.height);
    }

    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final pointPaint = Paint()..color = color;

    for (final (a, b) in connections) {
      final ja = pose[a];
      final jb = pose[b];
      if (ja.visibility >= 0.3 && jb.visibility >= 0.3) {
        canvas.drawLine(point(a), point(b), linePaint);
      }
    }

    for (var i = 0; i < PoseData.count; i++) {
      final j = pose[i];
      if (j.visibility >= 0.3) {
        canvas.drawCircle(point(i), 4, pointPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant PoseOverlayPainter oldDelegate) {
    return oldDelegate.pose != pose ||
        oldDelegate.mirror != mirror ||
        oldDelegate.color != color;
  }
}

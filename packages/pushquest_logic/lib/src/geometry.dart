import 'dart:math' as math;

import 'pose_data.dart';

double angleAt(Joint a, Joint b, Joint c) {
  final ax = a.x - b.x;
  final ay = a.y - b.y;
  final cx = c.x - b.x;
  final cy = c.y - b.y;
  final mag1 = math.sqrt(ax * ax + ay * ay);
  final mag2 = math.sqrt(cx * cx + cy * cy);
  if (mag1 == 0 || mag2 == 0) return 0;
  final dot = ax * cx + ay * cy;
  final cos = (dot / (mag1 * mag2)).clamp(-1.0, 1.0);
  return math.acos(cos) * 180 / math.pi;
}

double distance(Joint a, Joint b) {
  final dx = b.x - a.x;
  final dy = b.y - a.y;
  return math.sqrt(dx * dx + dy * dy);
}

double signedDistanceToLine(Joint p, Joint a, Joint b) {
  final vx = b.x - a.x;
  final vy = b.y - a.y;
  final len = math.sqrt(vx * vx + vy * vy);
  if (len == 0) return 0;
  return (vx * (p.y - a.y) - vy * (p.x - a.x)) / len;
}

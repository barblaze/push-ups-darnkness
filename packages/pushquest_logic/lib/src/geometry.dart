import 'dart:math' as math;

import 'pose_data.dart';

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

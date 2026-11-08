import 'dart:math' as math;
import 'dart:ui';

/// A visual connector for missing samples, distinct from measured chart data.
void drawDashedChartLine(Canvas canvas, Offset start, Offset end, Paint paint) {
  final distance = (end - start).distance;
  if (distance == 0) return;
  final direction = (end - start) / distance;
  const dash = 3.0;
  const gap = 4.0;
  for (var offset = 0.0; offset < distance; offset += dash + gap) {
    canvas.drawLine(
      start + direction * offset,
      start + direction * math.min(offset + dash, distance),
      paint,
    );
  }
}

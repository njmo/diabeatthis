import 'dart:math' as math;

import 'package:flutter/material.dart';

class CarbohydrateIcon extends StatelessWidget {
  const CarbohydrateIcon({super.key});

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: IconTheme.of(context).size ?? 24,
    child: CustomPaint(
      painter: CarbohydrateIconPainter(
        IconTheme.of(context).color ?? Theme.of(context).colorScheme.onSurface,
      ),
    ),
  );
}

class CarbohydrateIconPainter extends CustomPainter {
  const CarbohydrateIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()..color = color;
    canvas.drawLine(
      const Offset(12, 8),
      const Offset(12, 22),
      paint
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawOval(const Rect.fromLTWH(10, 1, 4, 7), paint);
    for (final y in [8.0, 13.0]) {
      for (final side in [-1, 1]) {
        canvas.save();
        canvas.translate(12 + side * 3.0, y);
        canvas.rotate(side * math.pi / 4);
        canvas.drawOval(
          Rect.fromCenter(center: Offset.zero, width: 4, height: 7),
          paint,
        );
        canvas.restore();
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(CarbohydrateIconPainter oldDelegate) =>
      color != oldDelegate.color;
}

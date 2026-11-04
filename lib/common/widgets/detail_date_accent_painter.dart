import 'package:flutter/material.dart';

class DetailDateAccentPainter extends CustomPainter {
  const DetailDateAccentPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(1, size.height * .75)
      ..cubicTo(
        size.width * .3,
        0,
        size.width * .65,
        size.height,
        size.width - 1,
        size.height * .2,
      );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant DetailDateAccentPainter oldDelegate) =>
      oldDelegate.color != color;
}

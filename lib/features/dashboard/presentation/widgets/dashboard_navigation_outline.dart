import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'dashboard_navigation_shape.dart';

class DashboardNavigationOutline extends CustomPainter {
  DashboardNavigationOutline({
    required this.geometry,
    required this.color,
    required this.leftInset,
  }) : super(repaint: geometry);

  final ValueListenable<ScaffoldGeometry> geometry;
  final Color color;
  final double leftInset;

  @override
  void paint(Canvas canvas, Size size) {
    final layout = geometry.value;
    final top = layout.bottomNavigationBarTop;
    final button = top == null
        ? null
        : layout.floatingActionButtonArea?.shift(Offset(-leftInset, -top));
    final path = const DashboardNavigationShape().getOuterPath(
      Offset.zero & size,
      button?.inflate(DashboardNavigationShape.notchMargin),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(DashboardNavigationOutline oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.leftInset != leftInset ||
      oldDelegate.geometry != geometry;
}

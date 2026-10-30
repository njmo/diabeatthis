import 'package:flutter/material.dart';

class DashboardNavigationShape extends NotchedShape {
  const DashboardNavigationShape({this.horizontalInset = 0});

  final double horizontalInset;

  static const double notchMargin = 4;

  @override
  Path getOuterPath(Rect host, Rect? guest) => Path.combine(
    PathOperation.intersect,
    const StadiumBorder().getOuterPath(host),
    const CircularNotchedRectangle().getOuterPath(
      host,
      guest?.shift(Offset(-horizontalInset, 0)),
    ),
  );
}

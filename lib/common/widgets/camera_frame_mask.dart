import 'dart:ui';

import 'package:flutter/material.dart';

class CameraFrameMask extends StatelessWidget {
  final Rect selection;

  const CameraFrameMask({super.key, required this.selection});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final frame = Rect.fromLTWH(
            selection.left * size.width,
            selection.top * size.height,
            selection.width * size.width,
            selection.height * size.height,
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              ClipPath(
                clipper: CameraFrameOutsideClipper(frame),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.45),
                  ),
                ),
              ),
              Positioned.fromRect(
                rect: frame,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class CameraFrameOutsideClipper extends CustomClipper<Path> {
  final Rect frame;

  const CameraFrameOutsideClipper(this.frame);

  @override
  Path getClip(Size size) => Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(Offset.zero & size)
    ..addRect(frame);

  @override
  bool shouldReclip(CameraFrameOutsideClipper oldClipper) =>
      oldClipper.frame != frame;
}

import 'package:flutter/material.dart';

class CameraSearchIcon extends StatelessWidget {
  final double size;

  const CameraSearchIcon({this.size = 24, super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Icon(Icons.photo_camera_outlined, size: size * 0.88),
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: Icon(Icons.search, size: size * 0.48),
          ),
        ],
      ),
    );
  }
}

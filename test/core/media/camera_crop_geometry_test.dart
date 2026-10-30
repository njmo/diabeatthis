import 'dart:ui';

import 'package:diabeatthis/core/media/camera_crop_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('name frame is centered and wide', () {
    final crop = cameraFrameSelection(const Size(300, 400), 2.5);
    expect(crop.center.dx, closeTo(0.5, 0.000001));
    expect(crop.center.dy, closeTo(0.5, 0.000001));
    expect(crop.width * 300 / (crop.height * 400), closeTo(2.5, 0.001));
    expect(crop.width, closeTo(0.9, 0.001));
  });

  test('tall frames stay within short camera previews', () {
    final crop = cameraFrameSelection(const Size(400, 200), 0.9);
    expect(crop.center.dx, closeTo(0.5, 0.000001));
    expect(crop.center.dy, closeTo(0.5, 0.000001));
    expect(crop.height, closeTo(0.85, 0.001));
    expect(crop.width, lessThan(1));
  });

  test('matching preview and photo proportions preserve the frame', () {
    const crop = Rect.fromLTWH(0.1, 0.2, 0.8, 0.6);
    expect(previewCropToPhoto(crop, 0.75, const Size(1200, 1600)), crop);
  });

  test('narrow preview maps to the center of a wider captured photo', () {
    final crop = previewCropToPhoto(
      const Rect.fromLTWH(0, 0, 1, 1),
      0.5,
      const Size(1200, 1600),
    );
    expect(crop.left, closeTo(1 / 6, 0.001));
    expect(crop.width, closeTo(2 / 3, 0.001));
    expect(crop.top, 0);
    expect(crop.height, 1);
  });

  test('wide preview maps to the center of a taller captured photo', () {
    final crop = previewCropToPhoto(
      const Rect.fromLTWH(0, 0, 1, 1),
      1,
      const Size(1200, 1600),
    );
    expect(crop.left, 0);
    expect(crop.width, 1);
    expect(crop.top, closeTo(0.125, 0.001));
    expect(crop.height, closeTo(0.75, 0.001));
  });
}

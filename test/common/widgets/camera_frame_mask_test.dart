import 'package:diabeatthis/common/widgets/camera_frame_mask.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('blur excludes the selected camera area', () {
    final clip = const CameraFrameOutsideClipper(
      Rect.fromLTWH(30, 100, 240, 200),
    ).getClip(const Size(300, 400));
    expect(clip.contains(const Offset(150, 200)), isFalse);
    expect(clip.contains(const Offset(10, 200)), isTrue);
    expect(clip.contains(const Offset(150, 20)), isTrue);
    expect(clip.contains(const Offset(150, 350)), isTrue);
  });

  testWidgets('camera mask leaves taps available to the camera preview', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 300,
            height: 400,
            child: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  onTap: () => tapped = true,
                  child: const ColoredBox(color: Colors.blue),
                ),
                const CameraFrameMask(
                  selection: Rect.fromLTWH(0.1, 0.25, 0.8, 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.tapAt(tester.getCenter(find.byType(CameraFrameMask)));
    expect(tapped, isTrue);
    expect(tester.takeException(), isNull);
  });
}

import 'package:diabeatthis/core/media/camera_photo_capture_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  group('CameraPhotoCaptureService', () {
    test('returns captured photo path', () async {
      final service = CameraPhotoCaptureService(
        pickFromCamera: () async => XFile('/tmp/front.jpg'),
      );

      final result = await service.capturePhoto();

      expect(result.state, CameraPhotoCaptureState.captured);
      expect(result.path, '/tmp/front.jpg');
      expect(result.hasPhoto, isTrue);
    });

    test('returns cancelled when picker returns null', () async {
      final service = CameraPhotoCaptureService(
        pickFromCamera: () async => null,
      );

      final result = await service.capturePhoto();

      expect(result.state, CameraPhotoCaptureState.cancelled);
      expect(result.hasPhoto, isFalse);
    });

    test('returns unavailable when picker throws platform exception', () async {
      final service = CameraPhotoCaptureService(
        pickFromCamera: () async {
          throw PlatformException(code: 'camera_unavailable');
        },
      );

      final result = await service.capturePhoto();

      expect(result.state, CameraPhotoCaptureState.unavailable);
      expect(result.hasPhoto, isFalse);
    });
  });
}

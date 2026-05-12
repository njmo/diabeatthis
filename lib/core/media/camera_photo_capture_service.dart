import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

enum CameraPhotoCaptureState { captured, cancelled, unavailable }

class CameraPhotoCaptureResult {
  final CameraPhotoCaptureState state;
  final String? path;

  const CameraPhotoCaptureResult._({required this.state, this.path});

  const CameraPhotoCaptureResult.captured(String path)
    : this._(state: CameraPhotoCaptureState.captured, path: path);

  const CameraPhotoCaptureResult.cancelled()
    : this._(state: CameraPhotoCaptureState.cancelled);

  const CameraPhotoCaptureResult.unavailable()
    : this._(state: CameraPhotoCaptureState.unavailable);

  bool get hasPhoto =>
      state == CameraPhotoCaptureState.captured && path != null;
}

class CameraPhotoCaptureService {
  final Future<XFile?> Function() pickFromCamera;

  CameraPhotoCaptureService({Future<XFile?> Function()? pickFromCamera})
    : pickFromCamera = pickFromCamera ?? _pickImageFromCamera;

  Future<CameraPhotoCaptureResult> capturePhoto() async {
    try {
      final photo = await pickFromCamera();
      if (photo == null) {
        return const CameraPhotoCaptureResult.cancelled();
      }

      return CameraPhotoCaptureResult.captured(photo.path);
    } on PlatformException {
      return const CameraPhotoCaptureResult.unavailable();
    }
  }
}

Future<XFile?> _pickImageFromCamera() {
  return ImagePicker().pickImage(
    source: ImageSource.camera,
    maxWidth: 1600,
    imageQuality: 85,
  );
}

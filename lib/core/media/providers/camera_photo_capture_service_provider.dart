import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../camera_photo_capture_service.dart';

part 'camera_photo_capture_service_provider.g.dart';

@riverpod
CameraPhotoCaptureService cameraPhotoCaptureService(Ref ref) {
  return CameraPhotoCaptureService();
}

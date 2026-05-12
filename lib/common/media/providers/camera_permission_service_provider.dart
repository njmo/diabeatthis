import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../camera_permission_service.dart';

part 'camera_permission_service_provider.g.dart';

@riverpod
CameraPermissionService cameraPermissionService(Ref ref) {
  return const CameraPermissionService();
}

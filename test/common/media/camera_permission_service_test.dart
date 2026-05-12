import 'package:diabeatthis/common/media/camera_permission_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  group('CameraPermissionService', () {
    test('returns granted without requesting again', () async {
      var requested = false;
      final service = CameraPermissionService(
        getStatus: () async => PermissionStatus.granted,
        requestPermission: () async {
          requested = true;
          return PermissionStatus.denied;
        },
      );

      final result = await service.requestCamera();

      expect(result.state, CameraPermissionState.granted);
      expect(result.canUseCamera, isTrue);
      expect(requested, isFalse);
    });

    test('requests camera when current status is denied', () async {
      var requested = false;
      final service = CameraPermissionService(
        getStatus: () async => PermissionStatus.denied,
        requestPermission: () async {
          requested = true;
          return PermissionStatus.granted;
        },
      );

      final result = await service.requestCamera();

      expect(result.state, CameraPermissionState.granted);
      expect(result.canUseCamera, isTrue);
      expect(requested, isTrue);
    });

    test('does not request when camera is permanently denied', () async {
      var requested = false;
      final service = CameraPermissionService(
        getStatus: () async => PermissionStatus.permanentlyDenied,
        requestPermission: () async {
          requested = true;
          return PermissionStatus.granted;
        },
      );

      final result = await service.requestCamera();

      expect(result.state, CameraPermissionState.permanentlyDenied);
      expect(result.canUseCamera, isFalse);
      expect(result.canOpenSettings, isTrue);
      expect(requested, isFalse);
    });
  });
}

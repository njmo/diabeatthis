import 'package:permission_handler/permission_handler.dart';

enum CameraPermissionState { granted, denied, permanentlyDenied, restricted }

class CameraPermissionResult {
  final CameraPermissionState state;

  const CameraPermissionResult(this.state);

  bool get canUseCamera => state == CameraPermissionState.granted;

  bool get canOpenSettings =>
      state == CameraPermissionState.permanentlyDenied ||
      state == CameraPermissionState.restricted;
}

class CameraPermissionService {
  final Future<PermissionStatus> Function() getStatus;
  final Future<PermissionStatus> Function() requestPermission;
  final Future<bool> Function() openSettings;

  const CameraPermissionService({
    this.getStatus = _getCameraStatus,
    this.requestPermission = _requestCameraPermission,
    this.openSettings = openAppSettings,
  });

  Future<CameraPermissionResult> requestCamera() async {
    final status = await getStatus();
    if (status.isGranted) {
      return const CameraPermissionResult(CameraPermissionState.granted);
    }
    if (status.isPermanentlyDenied) {
      return const CameraPermissionResult(
        CameraPermissionState.permanentlyDenied,
      );
    }
    if (status.isRestricted) {
      return const CameraPermissionResult(CameraPermissionState.restricted);
    }

    return _mapStatus(await requestPermission());
  }

  static CameraPermissionResult _mapStatus(PermissionStatus status) {
    if (status.isGranted) {
      return const CameraPermissionResult(CameraPermissionState.granted);
    }
    if (status.isPermanentlyDenied) {
      return const CameraPermissionResult(
        CameraPermissionState.permanentlyDenied,
      );
    }
    if (status.isRestricted) {
      return const CameraPermissionResult(CameraPermissionState.restricted);
    }
    return const CameraPermissionResult(CameraPermissionState.denied);
  }
}

Future<PermissionStatus> _getCameraStatus() {
  return Permission.camera.status;
}

Future<PermissionStatus> _requestCameraPermission() {
  return Permission.camera.request();
}

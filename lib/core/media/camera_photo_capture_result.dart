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

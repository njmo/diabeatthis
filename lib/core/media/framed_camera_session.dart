import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'photo_crop_service.dart';

class FramedCameraSession extends ChangeNotifier {
  CameraController? camera;
  bool busy = false;
  bool failed = false;
  bool disposed = false;
  int generation = 0;
  Future<void> lifecycle = Future.value();

  Future<void> start() {
    final request = ++generation;
    lifecycle = lifecycle.then((_) async {
      await releaseCamera();
      if (disposed || request != generation) return;
      failed = false;
      notifyListeners();
      CameraController? next;
      try {
        final cameras = await availableCameras();
        if (disposed || request != generation) return;
        final description = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first,
        );
        next = CameraController(
          description,
          ResolutionPreset.veryHigh,
          enableAudio: false,
        );
        await next.initialize();
        await next.lockCaptureOrientation(DeviceOrientation.portraitUp);
        if (disposed || request != generation) {
          await next.dispose();
          return;
        }
        camera = next;
      } catch (_) {
        await next?.dispose();
        if (!disposed && request == generation) failed = true;
      }
      if (!disposed && request == generation) notifyListeners();
    });
    return lifecycle;
  }

  Future<void> stop() {
    generation++;
    lifecycle = lifecycle.then((_) => releaseCamera());
    return lifecycle;
  }

  Future<void> releaseCamera() async {
    final previous = camera;
    camera = null;
    try {
      await previous?.dispose();
    } on CameraException {
      // The device may already have released the camera while backgrounding.
    }
  }

  Future<String?> capture(
    Rect selection,
    int maxDimension, {
    bool wholePhoto = false,
  }) async {
    final current = camera;
    if (busy || current == null || !current.value.isInitialized) return null;
    final request = generation;
    busy = true;
    failed = false;
    notifyListeners();
    String? originalPath;
    try {
      final photo = await current.takePicture();
      originalPath = photo.path;
      final result = await const PhotoCropService().prepare(
        photo.path,
        selection,
        maxDimension,
        previewAspectRatio: wholePhoto ? null : 1 / current.value.aspectRatio,
      );
      if (disposed || request != generation) {
        await File(result).delete();
        return null;
      }
      return result;
    } catch (_) {
      if (!disposed && request == generation) failed = true;
      return null;
    } finally {
      if (originalPath != null) {
        try {
          await File(originalPath).delete();
        } on FileSystemException {
          // Camera cache cleanup must not prevent accepting the prepared photo.
        }
      }
      busy = false;
      if (!disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    disposed = true;
    unawaited(stop());
    super.dispose();
  }
}

import 'dart:io';

import 'package:flutter/services.dart';

class ForegroundPowerLock {
  const ForegroundPowerLock._();

  static const _channel = MethodChannel('pl.diabeatthis/foreground_power_lock');

  static Future<void> acquireCollectTick({
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (!Platform.isAndroid) return;

    await _channel.invokeMethod<void>('acquireCollectTick', {
      'timeoutMillis': timeout.inMilliseconds,
    });
  }

  static Future<void> releaseCollectTick() async {
    if (!Platform.isAndroid) return;

    await _channel.invokeMethod<void>('releaseCollectTick');
  }
}

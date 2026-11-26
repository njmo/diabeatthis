import 'package:flutter/services.dart';

/// Registered in every Flutter engine, including the foreground service.
class CalculatorHandoff {
  const CalculatorHandoff();
  static const _channel = MethodChannel(
    'pl.diabeatthis.app/calculator_handoff',
  );

  Future<void> dismiss(String sessionId) async {
    try {
      await _channel.invokeMethod<void>('dismiss', {'sessionId': sessionId});
    } on MissingPluginException {
      // No calculator window exists on unsupported platforms.
    } on PlatformException {
      // Android may already have removed the window.
    }
  }

  Future<void> update(String sessionId, List<bool> completed) async {
    try {
      await _channel.invokeMethod<void>('update', {
        'sessionId': sessionId,
        'completed': completed,
      });
    } on MissingPluginException {
      // Unsupported platforms do not have a calculator window.
    } on PlatformException {
      // The user can still close the window manually.
    }
  }
}

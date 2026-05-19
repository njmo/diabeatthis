import 'package:flutter/services.dart';

class AapsReceiverController {
  const AapsReceiverController();

  static const MethodChannel _channel = MethodChannel(
    'pl.diabeatthis.app/aaps_receiver',
  );

  Future<void> setEnabled() async {
    await _channel.invokeMethod<void>('setEnabled');
  }

  Future<void> setDisabled() async {
    await _channel.invokeMethod<void>('setDisabled');
  }
}

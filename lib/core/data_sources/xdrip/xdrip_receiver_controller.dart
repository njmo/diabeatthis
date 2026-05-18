import 'package:flutter/services.dart';

class XdripReceiverController {
  const XdripReceiverController();

  static const MethodChannel _channel = MethodChannel(
    'pl.diabeatthis.app/xdrip_receiver',
  );

  Future<void> setEnabled() async {
    await _channel.invokeMethod<void>('setEnabled');
  }

  Future<void> setDisabled() async {
    await _channel.invokeMethod<void>('setDisabled');
  }
}

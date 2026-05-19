import 'package:flutter/services.dart';

import '../receiver/data_receiver_controller.dart';

class AapsReceiverController implements DataReceiverController {
  const AapsReceiverController();

  static const MethodChannel _channel = MethodChannel(
    'pl.diabeatthis.app/aaps_receiver',
  );

  @override
  Future<void> setEnabled() async {
    await _channel.invokeMethod<void>('setEnabled');
  }

  @override
  Future<void> setDisabled() async {
    await _channel.invokeMethod<void>('setDisabled');
  }
}

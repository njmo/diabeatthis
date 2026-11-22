import 'package:flutter/services.dart';

const _channel = MethodChannel('pl.diabeatthis.app/wear_notifications');

Future<bool> forwardWearMealInvitation(
  String requestId, {
  bool childResponse = false,
}) async {
  try {
    return await _channel
            .invokeMethod<bool>(childResponse ? 'answer' : 'invite', requestId)
            .timeout(const Duration(seconds: 3)) ??
        false;
  } on Exception {
    return false;
  }
}

Future<void> wakePhoneForMealInvitation(String channelId) async {
  try {
    await _channel.invokeMethod<void>('wakePhone', channelId);
  } on Exception {
    // The notification remains available.
  }
}

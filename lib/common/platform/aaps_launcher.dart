import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final aapsLauncherProvider = Provider<AapsLauncher>((ref) {
  return const AapsLauncher();
});

enum AapsLaunchResult { opened, unavailable, unsupported, failed }

class AapsLauncher {
  static const MethodChannel _defaultChannel = MethodChannel(
    'diabeatthis/aaps_launcher',
  );

  final MethodChannel _channel;

  const AapsLauncher({MethodChannel channel = _defaultChannel})
    : _channel = channel;

  Future<AapsLaunchResult> openAaps() async {
    try {
      final result = await _channel.invokeMethod<String>('openAaps');
      return switch (result) {
        'opened' => AapsLaunchResult.opened,
        'unavailable' => AapsLaunchResult.unavailable,
        'unsupported' => AapsLaunchResult.unsupported,
        _ => AapsLaunchResult.failed,
      };
    } on MissingPluginException {
      return AapsLaunchResult.unsupported;
    } on PlatformException {
      return AapsLaunchResult.failed;
    }
  }
}

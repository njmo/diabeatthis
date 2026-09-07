import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'external_app_installation_checker.dart';
import 'external_app_launcher_client.dart';

export 'external_app_launcher_client.dart'
    show ExternalAppLauncherClient, LaunchAppExternalAppLauncherClient;

final aapsLauncherProvider = Provider<AapsLauncher>((ref) {
  return const AapsLauncher();
});

enum AapsLaunchResult { opened, unavailable, unsupported, failed }

class AapsLauncher {
  final ExternalAppLauncherClient _client;
  final TargetPlatform? _targetPlatform;

  const AapsLauncher({
    this._client = const LaunchAppExternalAppLauncherClient(),
    this._targetPlatform,
  });

  Future<AapsLaunchResult> openAaps() async {
    if ((_targetPlatform ?? defaultTargetPlatform) != TargetPlatform.android) {
      return AapsLaunchResult.unsupported;
    }

    try {
      final isInstalled = await _client.isAppInstalled(
        androidPackageName: ExternalDataApp.aaps.androidPackageName,
      );
      if (!isInstalled) {
        return AapsLaunchResult.unavailable;
      }

      final result = await _client.openApp(
        androidPackageName: ExternalDataApp.aaps.androidPackageName,
        openStore: false,
      );

      return result == 1 ? AapsLaunchResult.opened : AapsLaunchResult.failed;
    } on UnsupportedError {
      return AapsLaunchResult.unsupported;
    } on MissingPluginException {
      return AapsLaunchResult.unsupported;
    } on Exception {
      return AapsLaunchResult.failed;
    }
  }
}

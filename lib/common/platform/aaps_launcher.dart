import 'package:external_app_launcher/external_app_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final aapsLauncherProvider = Provider<AapsLauncher>((ref) {
  return const AapsLauncher();
});

enum AapsLaunchResult { opened, unavailable, unsupported, failed }

class AapsLauncher {
  static const _aapsAndroidPackageName = 'info.nightscout.androidaps';

  final ExternalAppLauncherClient _client;
  final TargetPlatform? _targetPlatform;

  const AapsLauncher({
    ExternalAppLauncherClient client =
        const LaunchAppExternalAppLauncherClient(),
    TargetPlatform? targetPlatform,
  }) : _client = client,
       _targetPlatform = targetPlatform;

  Future<AapsLaunchResult> openAaps() async {
    if ((_targetPlatform ?? defaultTargetPlatform) != TargetPlatform.android) {
      return AapsLaunchResult.unsupported;
    }

    try {
      final isInstalled = await _client.isAppInstalled(
        androidPackageName: _aapsAndroidPackageName,
      );
      if (!isInstalled) {
        return AapsLaunchResult.unavailable;
      }

      final result = await _client.openApp(
        androidPackageName: _aapsAndroidPackageName,
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

abstract class ExternalAppLauncherClient {
  const ExternalAppLauncherClient();

  Future<bool> isAppInstalled({String? androidPackageName});

  Future<int> openApp({String? androidPackageName, bool? openStore});
}

class LaunchAppExternalAppLauncherClient implements ExternalAppLauncherClient {
  const LaunchAppExternalAppLauncherClient();

  @override
  Future<bool> isAppInstalled({String? androidPackageName}) async {
    final result = await LaunchApp.isAppInstalled(
      androidPackageName: androidPackageName,
    );

    return result == true;
  }

  @override
  Future<int> openApp({String? androidPackageName, bool? openStore}) {
    return LaunchApp.openApp(
      androidPackageName: androidPackageName,
      openStore: openStore,
    );
  }
}

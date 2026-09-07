import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'external_app_launcher_client.dart';

part 'external_app_installation_checker.g.dart';

@riverpod
ExternalAppInstallationChecker externalAppInstallationChecker(Ref ref) {
  return const ExternalAppInstallationChecker();
}

enum ExternalDataApp { aaps, xdrip }

extension ExternalDataAppPackageName on ExternalDataApp {
  String get androidPackageName {
    return switch (this) {
      ExternalDataApp.aaps => 'info.nightscout.androidaps',
      ExternalDataApp.xdrip => 'com.eveningoutpost.dexdrip',
    };
  }
}

class ExternalAppInstallationChecker {
  final ExternalAppLauncherClient _client;
  final TargetPlatform? _targetPlatform;

  const ExternalAppInstallationChecker({
    this._client = const LaunchAppExternalAppLauncherClient(),
    this._targetPlatform,
  });

  Future<bool> isInstalled(ExternalDataApp app) async {
    if ((_targetPlatform ?? defaultTargetPlatform) != TargetPlatform.android) {
      return false;
    }

    try {
      return await _client.isAppInstalled(
        androidPackageName: app.androidPackageName,
      );
    } on UnsupportedError {
      return false;
    } on MissingPluginException {
      return false;
    } on Exception {
      return false;
    }
  }
}

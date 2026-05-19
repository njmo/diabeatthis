import 'package:external_app_launcher/external_app_launcher.dart';

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

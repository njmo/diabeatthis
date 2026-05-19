import 'package:diabeatthis/common/platform/external_app_installation_checker.dart';
import 'package:diabeatthis/common/platform/external_app_launcher_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExternalAppInstallationChecker', () {
    test('checks AAPS Android package', () async {
      final client = _FakeExternalAppLauncherClient();
      final checker = ExternalAppInstallationChecker(
        client: client,
        targetPlatform: TargetPlatform.android,
      );

      await expectLater(
        checker.isInstalled(ExternalDataApp.aaps),
        completion(isTrue),
      );
      expect(client.requestedPackageNames, ['info.nightscout.androidaps']);
    });

    test('checks xDrip Android package', () async {
      final client = _FakeExternalAppLauncherClient();
      final checker = ExternalAppInstallationChecker(
        client: client,
        targetPlatform: TargetPlatform.android,
      );

      await expectLater(
        checker.isInstalled(ExternalDataApp.xdrip),
        completion(isTrue),
      );
      expect(client.requestedPackageNames, ['com.eveningoutpost.dexdrip']);
    });

    test('returns false outside Android without querying launcher', () async {
      final client = _FakeExternalAppLauncherClient();
      final checker = ExternalAppInstallationChecker(
        client: client,
        targetPlatform: TargetPlatform.iOS,
      );

      await expectLater(
        checker.isInstalled(ExternalDataApp.aaps),
        completion(isFalse),
      );
      expect(client.requestedPackageNames, isEmpty);
    });

    test('returns false when launcher throws', () async {
      final checker = ExternalAppInstallationChecker(
        client: _FakeExternalAppLauncherClient(exception: Exception('failed')),
        targetPlatform: TargetPlatform.android,
      );

      await expectLater(
        checker.isInstalled(ExternalDataApp.aaps),
        completion(isFalse),
      );
    });
  });
}

class _FakeExternalAppLauncherClient implements ExternalAppLauncherClient {
  _FakeExternalAppLauncherClient({this.exception});

  final Object? exception;
  final List<String?> requestedPackageNames = [];

  @override
  Future<bool> isAppInstalled({String? androidPackageName}) async {
    requestedPackageNames.add(androidPackageName);

    final exception = this.exception;
    if (exception != null) {
      throw exception;
    }

    return true;
  }

  @override
  Future<int> openApp({String? androidPackageName, bool? openStore}) {
    throw UnimplementedError();
  }
}

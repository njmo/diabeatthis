import 'package:diabeatthis/common/platform/aaps_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AapsLauncher', () {
    test(
      'returns opened when AAPS is installed and external launcher succeeds',
      () async {
        final launcher = AapsLauncher(
          client: _FakeExternalAppLauncherClient(),
          targetPlatform: TargetPlatform.android,
        );

        await expectLater(
          launcher.openAaps(),
          completion(AapsLaunchResult.opened),
        );
      },
    );

    test('returns unavailable when AAPS is not installed', () async {
      final client = _FakeExternalAppLauncherClient(isInstalled: false);
      final launcher = AapsLauncher(
        client: client,
        targetPlatform: TargetPlatform.android,
      );

      await expectLater(
        launcher.openAaps(),
        completion(AapsLaunchResult.unavailable),
      );
      expect(client.openAppCallCount, 0);
    });

    test('returns failed when external launcher cannot open AAPS', () async {
      final launcher = AapsLauncher(
        client: _FakeExternalAppLauncherClient(openResult: 0),
        targetPlatform: TargetPlatform.android,
      );

      await expectLater(
        launcher.openAaps(),
        completion(AapsLaunchResult.failed),
      );
    });

    test('returns failed when external launcher throws', () async {
      final launcher = AapsLauncher(
        client: _FakeExternalAppLauncherClient(exception: Exception('failed')),
        targetPlatform: TargetPlatform.android,
      );

      await expectLater(
        launcher.openAaps(),
        completion(AapsLaunchResult.failed),
      );
    });

    test('returns unsupported when external launcher is unsupported', () async {
      final launcher = AapsLauncher(
        client: _FakeExternalAppLauncherClient(
          exception: UnsupportedError('unsupported'),
        ),
        targetPlatform: TargetPlatform.android,
      );

      await expectLater(
        launcher.openAaps(),
        completion(AapsLaunchResult.unsupported),
      );
    });

    test('returns unsupported outside Android', () async {
      final client = _FakeExternalAppLauncherClient();
      final launcher = AapsLauncher(
        client: client,
        targetPlatform: TargetPlatform.iOS,
      );

      await expectLater(
        launcher.openAaps(),
        completion(AapsLaunchResult.unsupported),
      );
      expect(client.openAppCallCount, 0);
    });
  });
}

class _FakeExternalAppLauncherClient implements ExternalAppLauncherClient {
  _FakeExternalAppLauncherClient({
    this.isInstalled = true,
    this.openResult = 1,
    this.exception,
  });

  final bool isInstalled;
  final int openResult;
  final Object? exception;
  int openAppCallCount = 0;

  @override
  Future<bool> isAppInstalled({String? androidPackageName}) async {
    final exception = this.exception;
    if (exception != null) {
      throw exception;
    }

    return isInstalled;
  }

  @override
  Future<int> openApp({String? androidPackageName, bool? openStore}) async {
    openAppCallCount += 1;

    final exception = this.exception;
    if (exception != null) {
      throw exception;
    }

    return openResult;
  }
}

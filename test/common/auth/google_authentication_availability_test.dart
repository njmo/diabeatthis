import 'package:diabeatthis/common/auth/firebase_google_authentication_repository.dart';
import 'package:diabeatthis/firebase_options.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'unconfigured platforms do not initialize Firebase or offer fake authentication',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final repository = FirebaseGoogleAuthenticationRepository();
      expect(repository.isSupported, isFalse);
      expect(await repository.watchAccount().first, isNull);
      await expectLater(repository.signIn(), throwsUnsupportedError);
      await repository.signOut();
    },
  );

  test('iOS supports Google sign-in for the configured App ID', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final repository = FirebaseGoogleAuthenticationRepository();
    expect(repository.isSupported, isTrue);
    final options = DefaultFirebaseOptions.currentPlatform;
    expect(options.iosBundleId, 'pl.diabeatthis.app');
    expect(options.iosClientId, isNotEmpty);
  });
}

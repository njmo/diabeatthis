import 'package:diabeatthis/core/firebase/firebase_app_check_provider.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('createAndroidAppCheckProvider', () {
    test('uses Play Integrity in release mode', () async {
      final provider = await createAndroidAppCheckProvider(isReleaseMode: true);

      expect(provider, isA<AndroidPlayIntegrityProvider>());
    });

    test('uses stored debug token outside release mode', () async {
      const debugToken = '11111111-1111-4111-8111-111111111111';
      SharedPreferences.setMockInitialValues({
        firebaseAppCheckDebugTokenKey: debugToken,
      });

      final provider = await createAndroidAppCheckProvider(
        isReleaseMode: false,
      );

      expect(provider, isA<AndroidDebugProvider>());
      expect((provider as AndroidDebugProvider).debugToken, debugToken);
    });
  });
}

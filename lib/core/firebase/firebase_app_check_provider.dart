import 'dart:math';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

const firebaseAppCheckDebugTokenKey = 'firebase_app_check_debug_token';

Future<AndroidAppCheckProvider> createAndroidAppCheckProvider({
  bool isReleaseMode = kReleaseMode,
}) async {
  if (isReleaseMode) {
    return const AndroidPlayIntegrityProvider();
  }

  final debugToken = await readOrCreateFirebaseAppCheckDebugToken();
  return AndroidDebugProvider(debugToken: debugToken);
}

Future<String> readOrCreateFirebaseAppCheckDebugToken() async {
  final prefs = await SharedPreferences.getInstance();
  final existingToken = prefs.getString(firebaseAppCheckDebugTokenKey);
  if (existingToken != null && existingToken.isNotEmpty) {
    debugPrint('Firebase App Check debug token: $existingToken');
    return existingToken;
  }

  final token = createFirebaseAppCheckDebugToken();
  await prefs.setString(firebaseAppCheckDebugTokenKey, token);
  debugPrint(
    'Firebase App Check debug token created: $token. '
    'Register it in Firebase Console App Check debug tokens.',
  );
  return token;
}

String createFirebaseAppCheckDebugToken() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-'
      '${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}

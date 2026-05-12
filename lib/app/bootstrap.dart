import 'dart:async';
import 'dart:math';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/logger/logger.dart';
import '../firebase_options.dart';
import 'app_container.dart';

const _firebaseAppCheckDebugTokenKey = 'firebase_app_check_debug_token';

typedef BootstrapBuilder = FutureOr<Widget> Function();
Future<void> bootstrap(BootstrapBuilder builder) async {
  // Optional: make zone errors fatal. Must be the first statement.
  BindingBase.debugZoneErrorsAreFatal = true;

  await runZonedGuarded<Future<void>>(
    () async {
      // Ensure binding inside the same zone as runApp ✅
      WidgetsFlutterBinding.ensureInitialized();

      // Also set error app inside this zone
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        // send to crash reporter if you like
      };

      // Initialize communication port
      await AndroidAlarmManager.initialize();
      FlutterForegroundTask.initCommunicationPort();

      LogRuntimeConfig.configure(enableBuffer: true, capacity: 20000);

      /*
      if (kDebugMode) {
        debugRepaintRainbowEnabled = true;
      }
      */

      await _initializeFirebase();

      final app = await builder();
      runApp(
        UncontrolledProviderScope(container: appContainer, child: app),
      ); // Same zone ✅
    },
    (Object error, StackTrace stack) {
      debugPrint('Uncaught: $error\n$stack');
      // send to crash reporter if you like
    },
  );
}

Future<void> _initializeFirebase() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return;
  }

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  await _activateFirebaseAppCheck();
}

Future<void> _activateFirebaseAppCheck() async {
  // TODO: Switch release builds to AndroidPlayIntegrityProvider before
  // distributing the app outside local testing.
  final debugToken = await _readOrCreateFirebaseAppCheckDebugToken();
  await FirebaseAppCheck.instance.activate(
    providerAndroid: AndroidDebugProvider(debugToken: debugToken),
  );
}

Future<String> _readOrCreateFirebaseAppCheckDebugToken() async {
  final prefs = await SharedPreferences.getInstance();
  final existingToken = prefs.getString(_firebaseAppCheckDebugTokenKey);
  if (existingToken != null && existingToken.isNotEmpty) {
    debugPrint('Firebase App Check debug token: $existingToken');
    return existingToken;
  }

  final token = _createDebugToken();
  await prefs.setString(_firebaseAppCheckDebugTokenKey, token);
  debugPrint(
    'Firebase App Check debug token created: $token. '
    'Register it in Firebase Console App Check debug tokens.',
  );
  return token;
}

String _createDebugToken() {
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

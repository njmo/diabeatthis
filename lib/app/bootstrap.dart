import 'dart:async';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/app_mode/application_device_mode.dart';
import '../common/meal_advisor/notifications/meal_decision_push.dart';
import '../core/firebase/firebase_app_check_provider.dart';
import '../core/logger/logger.dart';
import '../firebase_options.dart';
import 'app_container.dart';

typedef BootstrapBuilder = FutureOr<Widget> Function();
Future<void> bootstrap(
  BootstrapBuilder builder, {
  ProviderContainer? container,
}) async {
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
      if (await loadApplicationDeviceMode() == ApplicationDeviceMode.patient) {
        await AndroidAlarmManager.initialize();
        FlutterForegroundTask.initCommunicationPort();
      }

      LogRuntimeConfig.configure(enableBuffer: true, capacity: 20000);

      /*
      if (kDebugMode) {
        debugRepaintRainbowEnabled = true;
      }
      */

      await _initializeFirebase();
      if (!kIsWeb &&
          defaultTargetPlatform == TargetPlatform.android &&
          Firebase.apps.isNotEmpty) {
        FirebaseMessaging.onBackgroundMessage(
          mealDecisionFirebaseBackgroundHandler,
        );
      }

      final app = await builder();
      runApp(
        UncontrolledProviderScope(
          container: container ?? appContainer,
          child: app,
        ),
      ); // Same zone ✅
    },
    (Object error, StackTrace stack) {
      debugPrint('Uncaught: $error\n$stack');
      // send to crash reporter if you like
    },
  );
}

Future<void> _initializeFirebase() async {
  if (kIsWeb ||
      (defaultTargetPlatform != TargetPlatform.android &&
          !isCaregiverOnlyPlatform)) {
    return;
  }

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  await activateFamilyAppCheck();
}

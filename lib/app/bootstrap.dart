import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_container.dart';

typedef BootstrapBuilder = FutureOr<Widget> Function();
Future<void> bootstrap(BootstrapBuilder builder) async {
  // Optional: make zone errors fatal. Must be the first statement.
  BindingBase.debugZoneErrorsAreFatal = true;

  await runZonedGuarded<Future<void>>(
    () async {
      // Ensure binding inside the same zone as runApp ✅
      WidgetsFlutterBinding.ensureInitialized();

      // Also set error handlers inside this zone
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
        // send to crash reporter if you like
      };

      // Initialize communication port
      FlutterForegroundTask.initCommunicationPort();

      // Do any other init that might touch bindings here (Firebase, etc.)

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

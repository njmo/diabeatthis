import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef BootstrapBuilder = FutureOr<Widget> Function();

Future<void> bootstrap(BootstrapBuilder builder) async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
  };

  await runZonedGuarded<Future<void>>(
    () async {
      final app = await builder();
      runApp(ProviderScope(child: app));
    },
    (Object error, StackTrace stack) {
      debugPrint('Uncaught: $error\n$stack');
    },
  );
}

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'router/observers/router_debug_observer.dart';
import 'router/providers/app_router_provider.dart';
import 'router/providers/flutter_local_notifications_plugin_provider.dart';

void initNotifications(WidgetRef ref)  {
  final flutterLocalNotificationsPlugin = ref.watch(flutterLocalNotificationsPluginProvider);

  tz.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Europe/Warsaw'));

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  const initSettings = InitializationSettings(
    android: androidInit,
    iOS: iosInit,
  );

  flutterLocalNotificationsPlugin.initialize(settings: initSettings);
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    initNotifications(ref);

    return MaterialApp.router(
      title: 'Flutter + auto_route + Riverpod',
      routerConfig: router.config(
        navigatorObservers: () => [
          AutoRouteDebugObserver()
        ],
      ),
      theme: ThemeData(
        textTheme: GoogleFonts.nunitoSansTextTheme(),
        useMaterial3: true,
      ),
    );
  }
}

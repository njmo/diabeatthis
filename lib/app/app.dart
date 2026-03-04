import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import 'router/observers/router_debug_observer.dart';
import 'router/providers/app_router_provider.dart';
import 'router/providers/flutter_local_notifications_plugin_provider.dart';

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(notificationsInitProvider);

    final router = ref.watch(appRouterProvider);

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

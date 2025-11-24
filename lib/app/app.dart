import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'router/app_router.dart';
import 'router/observers/router_debug_observer.dart';

class MyApp extends StatelessWidget {
  final AppRouter _router;
  const MyApp({super.key, required AppRouter router}) : _router = router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Flutter + auto_route + Riverpod',
      routerConfig: _router.config(
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

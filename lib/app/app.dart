import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import 'router/app_router.dart';

class MyApp extends StatelessWidget {
  final AppRouter _router;
  const MyApp({super.key, required AppRouter router}) : _router = router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Flutter + auto_route + Riverpod',
      routerConfig: _router.config(
        navigatorObservers: () => [AutoRouteObserver()],
      ),
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6750A4),
        useMaterial3: true,
      ),
    );
  }
}

import 'package:auto_route/auto_route.dart';
import 'package:flutter/cupertino.dart';

class AutoRouteDebugObserver extends AutoRouteObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    debugPrint('➡️ Pushed route: ${route.settings.name}');
    super.didPush(route, previousRoute);
  }

  @override
  void didPop(Route route, Route? previousRoute) {
    debugPrint('⬅️ Popped route: ${route.settings.name}');
    super.didPop(route, previousRoute);
  }
}

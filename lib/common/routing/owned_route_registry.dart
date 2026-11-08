import 'package:flutter/widgets.dart';

/// Tracks only routes opened for a particular short-lived owner.
class OwnedRouteRegistry {
  static final Map<Object, Set<Route<dynamic>>> _routes = {};

  static void register(Object owner, Route<dynamic> route) {
    (_routes[owner] ??= <Route<dynamic>>{}).add(route);
  }

  static void unregister(Object owner, Route<dynamic> route) {
    final routes = _routes[owner];
    routes?.remove(route);
    if (routes?.isEmpty == true) _routes.remove(owner);
  }

  static void close(Object owner) {
    final routes =
        _routes.remove(owner)?.toList().reversed ?? const <Route<dynamic>>[];
    for (final route in routes) {
      final navigator = route.navigator;
      if (route.isActive && navigator != null && navigator.mounted) {
        navigator.removeRoute(route);
      }
    }
  }
}

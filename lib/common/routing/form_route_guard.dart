import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef FormRouteGuard = Widget Function(Widget child);

/// Source scopes can protect nested sheets/dialogs without branching their UI.
final formRouteGuardProvider = Provider<FormRouteGuard>(
  (_) =>
      (child) => child,
);

FormRouteGuard formRouteGuardOf(BuildContext context) {
  ProviderContainer container;
  try {
    container = ProviderScope.containerOf(context, listen: false);
  } on StateError {
    return (child) => child;
  } // A standalone presentational widget.
  return container.read(formRouteGuardProvider);
}

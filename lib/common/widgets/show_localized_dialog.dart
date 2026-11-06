import 'package:flutter/material.dart';

/// Carries a session-local locale across the navigator's overlay boundary.
Future<T?> showLocalizedDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  final locale = Localizations.localeOf(context);
  return showDialog<T>(
    context: context,
    builder: (dialogContext) => Localizations.override(
      context: dialogContext,
      locale: locale,
      child: Builder(builder: builder),
    ),
  );
}

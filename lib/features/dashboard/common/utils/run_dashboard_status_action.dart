import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';

Future<void> runDashboardStatusAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.lang.dashboardTargetActionFailed)),
      );
    }
  }
}

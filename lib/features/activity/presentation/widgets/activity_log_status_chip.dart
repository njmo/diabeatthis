import 'package:flutter/material.dart';

import '../../../../common/activity/activity_session_state.dart';
import '../../../../common/l10n/language.dart';
import '../utils/activity_log_formatters.dart';

class ActivityLogStatusChip extends StatelessWidget {
  final ActivitySessionState state;

  const ActivityLogStatusChip({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final active = state == ActivitySessionState.active;
    final scheme = Theme.of(context).colorScheme;
    final background = active
        ? scheme.primaryContainer
        : scheme.surfaceContainerHighest;
    final foreground = active
        ? scheme.onPrimaryContainer
        : scheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        activitySessionStateLabel(context.lang, state),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

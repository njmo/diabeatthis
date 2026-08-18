import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';

class ActivityLogStatusChip extends StatelessWidget {
  final bool active;

  const ActivityLogStatusChip({super.key, required this.active});

  @override
  Widget build(BuildContext context) {
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
        active ? context.lang.activityActive : context.lang.activityFinished,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

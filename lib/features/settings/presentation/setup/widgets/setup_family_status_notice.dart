import 'package:flutter/material.dart';

import '../../../../../common/l10n/language.dart';

/// Notice card presented during family membership synchronization, failures or lock.
class SetupFamilyStatusNotice extends StatelessWidget {
  const SetupFamilyStatusNotice({
    super.key,
    required this.isPending,
    this.onRetry,
    this.hasFailed = false,
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  final bool isPending;
  final bool hasFailed;
  final VoidCallback? onRetry;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    if (hasFailed) {
      return Container(
        margin: margin,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.errorContainer.withValues(alpha: .35),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: colors.error.withValues(alpha: .25),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.sync_problem, size: 20, color: colors.error),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.lang.setupFamilyMembersFailed,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.refresh, size: 16),
                  onPressed: onRetry,
                  label: Text(context.lang.setupRefreshFamilyMembers),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: colors.error,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    if (isPending) {
      return Container(
        margin: margin,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: colors.primaryContainer.withValues(alpha: .38),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: colors.primary.withValues(alpha: .25),
          ),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.lang.familyLoadingTitle,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.lang.familyLoadingExplanation,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: margin,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: .45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colors.outlineVariant.withValues(alpha: .35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, size: 20, color: colors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.lang.setupFamilyDisconnectBeforeDisable,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

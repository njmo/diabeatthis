import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../features/low_treatment/domain/models/low_treatment_handoff_pending.dart';
import '../../l10n/language.dart';
import '../../theme/app_design_tokens.dart';

Future<bool> showFamilyTreatmentAapsReview(
  BuildContext context,
  LowTreatmentHandoffPending pending,
) async {
  final strings = context.lang;
  final minutes = clock.now().difference(pending.savedAt).inMinutes;
  final elapsed = minutes <= 0
      ? strings.relativeTimeNow
      : strings.relativeTimeMinutesAgo(minutes);
  final carbs = NumberFormat(
    '0.###',
    strings.localeName,
  ).format(pending.expectedCarbs);

  return await showModalBottomSheet<bool>(
        context: context,
        showDragHandle: true,
        useSafeArea: true,
        isScrollControlled: true,
        builder: (context) {
          final theme = Theme.of(context);
          final colors = theme.colorScheme;
          return SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.xs,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    strings.familyChatTreatmentRecorded,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHigh,
                      borderRadius: AppRadius.cardBorderRadius,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.aapsPipCarbs,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            '$carbs g',
                            style: theme.textTheme.headlineMedium,
                          ),
                          Text(
                            elapsed,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: Text(strings.familyChatEnterCarbsInAaps),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(strings.activityEntryLater),
                  ),
                ],
              ),
            ),
          );
        },
      ) ??
      false;
}

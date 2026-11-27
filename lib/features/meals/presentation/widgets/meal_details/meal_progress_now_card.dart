import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/monitoring/meal_wait_status.dart';
import '../../../../../common/widgets/summary_detail_card.dart';
import '../../models/meal_progress_now.dart';
import 'meal_detail_formatters.dart';

enum _StepState { done, pending, missing }

/// The current step of a meal in progress and what it still waits for.
class MealProgressNowCard extends ConsumerWidget {
  const MealProgressNowCard({super.key, required this.progress});

  final MealProgressNow progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = context.lang;
    final theme = Theme.of(context);
    final now = clock.now();
    final wait = progress.waitsBeforeEating
        ? ref.watch(mealWaitStatusProvider).value
        : null;
    final carbs = progress.extendedCarbs;
    final waitingForExtendedCarbs =
        wait?.waitingForExtendedCarbs == true ||
        (progress.waitsBeforeEating && carbs != null && carbs.entered == null);
    final waitEndsAt = progress.waitEndsAt;
    final waitOver = waitEndsAt == null || !waitEndsAt.isAfter(now);
    final headline = !progress.waitsBeforeEating
        ? mealStatusLabel(progress.status)
        : !waitOver
        ? lang.mealProgressNowWaitingUntil(mealTime(waitEndsAt))
        : waitingForExtendedCarbs
        ? lang.mealProgressNowWaitingForExtendedCarbs
        : lang.mealProgressNowCanEat;
    final grams = NumberFormat('0.#', lang.localeName);
    final calculator = progress.calculator;

    return SummaryDetailCard(
      title: lang.mealProgressNowTitle,
      icon: Icons.hourglass_top_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(headline, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          _StepRow(
            state: calculator == null ? _StepState.missing : _StepState.done,
            title: calculator == null
                ? lang.mealProgressNowCalculator
                : '${lang.mealProgressNowCalculator} ${grams.format(calculator.carbs)} g',
            trailing: calculator == null
                ? lang.mealProgressNowMissing
                : mealTime(calculator.createdAt),
          ),
          _StepRow(
            state: progress.bolusAt == null
                ? _StepState.pending
                : _StepState.done,
            title: lang.mealProgressNowBolus,
            trailing: progress.bolusAt == null
                ? lang.mealProgressNowPending
                : mealTime(progress.bolusAt!),
          ),
          if (progress.waitMinutes != null && waitEndsAt != null)
            _StepRow(
              state: waitOver ? _StepState.done : _StepState.pending,
              title: lang.mealProgressNowWait(progress.waitMinutes!),
              trailing: lang.mealProgressNowUntil(mealTime(waitEndsAt)),
            ),
          if (carbs != null)
            _StepRow(
              state: carbs.entered != null
                  ? _StepState.done
                  : _StepState.missing,
              title: lang.mealProgressNowExtendedCarbs(
                carbs.grams,
                carbs.durationMinutes,
              ),
              trailing: carbs.entered != null
                  ? lang.mealProgressNowStartedAt(
                      mealTime(carbs.entered!.createdAt),
                    )
                  : lang.mealProgressNowMissing,
              detail: carbs.entered == null && carbs.expectedStart != null
                  ? lang.mealProgressNowExpectedStart(
                      mealTime(carbs.expectedStart!),
                    )
                  : null,
            ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.state,
    required this.title,
    required this.trailing,
    this.detail,
  });

  final _StepState state;
  final String title;
  final String trailing;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final (icon, color) = switch (state) {
      _StepState.done => (Icons.check_circle_rounded, scheme.primary),
      _StepState.pending => (Icons.schedule_rounded, scheme.onSurfaceVariant),
      _StepState.missing => (Icons.cancel_rounded, scheme.error),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                if (detail != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    detail!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            trailing,
            style: theme.textTheme.labelMedium?.copyWith(
              color: state == _StepState.missing ? scheme.error : null,
            ),
          ),
        ],
      ),
    );
  }
}

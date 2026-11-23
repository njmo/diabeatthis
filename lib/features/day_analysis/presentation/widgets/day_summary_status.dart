import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/responsive_bottom_sheet.dart';
import '../../data/providers/day_summary_provider.dart';
import '../../domain/use_cases/accept_day_summary_use_case.dart';
import 'day_summary_sheet.dart';

class DaySummaryStatus extends ConsumerWidget {
  final DateTime date;
  const DaySummaryStatus({super.key, required this.date});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = context.lang;
    if (!AcceptDaySummaryUseCase.isAvailable(date, clock.now())) {
      return Tooltip(
        message: lang.daySummaryAvailableTomorrow,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.timelapse_rounded,
                size: 14,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  lang.dayInProgressTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return ref
        .watch(acceptedDaySummaryProvider(date))
        .when(
          loading: () => const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          error: (_, _) => IconButton(
            tooltip: lang.dayReviewArchiveFailed,
            onPressed: () => ref.invalidate(acceptedDaySummaryProvider(date)),
            icon: const Icon(Icons.refresh, size: 18),
          ),
          data: (accepted) => TextButton.icon(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: () => showResponsiveBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (_) => FractionallySizedBox(
                heightFactor: .9,
                child: DaySummarySheet(date: date),
              ),
            ),
            icon: Icon(
              accepted != null
                  ? Icons.check_circle_outline
                  : Icons.fact_check_outlined,
              size: 17,
            ),
            label: Text(
              accepted != null
                  ? lang.daySummaryViewShort
                  : lang.daySummaryActionShort,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
  }
}

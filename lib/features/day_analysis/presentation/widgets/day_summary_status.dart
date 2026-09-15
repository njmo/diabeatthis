import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../data/providers/day_summary_provider.dart';
import '../../domain/use_cases/accept_day_summary_use_case.dart';
import 'day_summary_sheet.dart';

class DaySummaryStatus extends ConsumerWidget {
  final DateTime date;
  const DaySummaryStatus({super.key, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = context.lang;
    return ref
        .watch(acceptedDaySummaryProvider(date))
        .when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => TextButton.icon(
            onPressed: () => ref.invalidate(acceptedDaySummaryProvider(date)),
            icon: const Icon(Icons.warning_amber_rounded),
            label: Text(lang.dayReviewArchiveFailed),
          ),
          data: (accepted) {
            void openSummary() => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              builder: (_) => FractionallySizedBox(
                heightFactor: 0.9,
                child: DaySummarySheet(date: date),
              ),
            );
            if (accepted != null) {
              return OutlinedButton.icon(
                onPressed: openSummary,
                icon: const Icon(Icons.check_circle, color: Colors.green),
                label: Text(lang.daySummaryAcceptedView),
              );
            }
            if (!AcceptDaySummaryUseCase.isAvailable(date, clock.now())) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(lang.daySummaryAvailableTomorrow),
              );
            }
            return FilledButton.icon(
              onPressed: openSummary,
              icon: const Icon(Icons.fact_check_outlined),
              label: Text(lang.daySummaryNotAcceptedAction),
            );
          },
        );
  }
}

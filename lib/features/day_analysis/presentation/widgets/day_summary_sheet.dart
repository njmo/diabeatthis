import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../common/l10n/language.dart';
import '../../data/providers/day_context_provider.dart';
import '../../data/providers/day_low_treatment_review_provider.dart';
import '../../data/providers/day_meal_review_provider.dart';
import '../../data/providers/day_summary_provider.dart';
import '../../domain/models/day_summary_snapshot.dart';
import '../../domain/use_cases/accept_day_summary_use_case.dart';
import '../controllers/day_summary_controller.dart';
import 'day_summary_review_form.dart';

class DaySummarySheet extends ConsumerWidget {
  final DateTime date;
  const DaySummarySheet({super.key, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saving = ref.watch(daySummaryControllerProvider(date)).isLoading;
    final archive = ref.watch(acceptedDaySummaryProvider(date));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.lang.daySummaryDated(
                  DateFormat(
                    'dd.MM.yyyy',
                    context.lang.localeName,
                  ).format(date),
                ),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              archive.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, _) => TextButton(
                  onPressed: () =>
                      ref.invalidate(acceptedDaySummaryProvider(date)),
                  child: Text(context.lang.dayReviewArchiveFailed),
                ),
                data: (accepted) {
                  if (accepted != null) {
                    return Column(
                      children: [
                        Text(
                          context.lang.daySummaryAcceptedAt(
                            DateFormat(
                              'dd.MM.yyyy HH:mm',
                              context.lang.localeName,
                            ).format(accepted.displayAcceptedAt),
                          ),
                        ),
                        DaySummaryReviewForm(snapshot: accepted.snapshot),
                      ],
                    );
                  }
                  return ref
                      .watch(daySummaryDraftProvider(date))
                      .when(
                        skipLoadingOnRefresh: false,
                        loading: () => const LinearProgressIndicator(),
                        error: (_, _) => TextButton(
                          onPressed: () {
                            ref.invalidate(dayContextForDateProvider(date));
                            ref.invalidate(dayMealReviewProvider(date));
                            ref.invalidate(dayLowTreatmentReviewProvider(date));
                            ref.invalidate(daySummaryDraftProvider(date));
                          },
                          child: Text(context.lang.dayReviewBuildFailed),
                        ),
                        data: (snapshot) => DaySummaryReviewForm(
                          key: ValueKey(snapshot.encode()),
                          snapshot: snapshot,
                          saving: saving,
                          onAccept: (skipped, acknowledge) => _accept(
                            context,
                            ref,
                            snapshot,
                            skipped,
                            acknowledge,
                          ),
                        ),
                      );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _accept(
    BuildContext context,
    WidgetRef ref,
    DaySummarySnapshot snapshot,
    Set<int> skipped,
    bool acknowledge,
  ) async {
    try {
      await ref
          .read(daySummaryControllerProvider(date).notifier)
          .confirm(
            snapshot,
            skippedRecords: skipped,
            acknowledgeLimitations: acknowledge,
          );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error is StaleDaySummary
                ? context.lang.dayReviewStaleSummary
                : context.lang.dayReviewAcceptFailed,
          ),
        ),
      );
      ref.invalidate(acceptedDaySummaryProvider(date));
    }
  }
}

import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/drift/providers/database_provider.dart';
import '../../../low_treatment/domain/models/low_treatment_review_entry.dart';
import '../../domain/models/accepted_day_summary.dart';
import '../../domain/models/day_meal_review_entry.dart';
import '../../domain/models/day_summary_snapshot.dart';
import '../../domain/use_cases/build_day_summary_snapshot_use_case.dart';
import '../repositories/day_summary_repository.dart';
import 'day_context_provider.dart';
import 'day_low_treatment_review_provider.dart';
import 'day_meal_review_provider.dart';

final daySummaryRepositoryProvider = Provider(
  (ref) => DaySummaryRepository(ref.watch(databaseProvider)),
);

final daySummaryDraftProvider = FutureProvider.autoDispose
    .family<DaySummarySnapshot, DateTime>((ref, date) async {
      final today = clock.now().toLocal();
      final context = ref.watch(
        (date == DateTime(today.year, today.month, today.day)
                ? dayContextProvider
                : dayContextForDateProvider(date))
            .future,
      );
      final meals = ref
          .watch(dayMealReviewProvider(date).future)
          .then<List<DayMealReviewEntry>?>(
            (value) => value,
            onError: (Object _, StackTrace _) => null,
          );
      final lows = ref
          .watch(dayLowTreatmentReviewProvider(date).future)
          .then<List<LowTreatmentReviewEntry>?>(
            (value) => value,
            onError: (Object _, StackTrace _) => null,
          );
      return const BuildDaySummarySnapshotUseCase()(
        await context,
        meals: await meals,
        lows: await lows,
      );
    });

/// The archive can be read without loading any live history.
final acceptedDaySummaryProvider = FutureProvider.autoDispose
    .family<AcceptedDaySummary?, DateTime>(
      (ref, date) =>
          ref.watch(daySummaryRepositoryProvider).get(daySummaryKey(date)),
    );

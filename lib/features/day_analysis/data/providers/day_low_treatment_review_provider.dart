import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../low_treatment/data/providers/low_treatment_review_repository_provider.dart';
import '../../../low_treatment/domain/models/low_treatment_review_decision.dart';
import '../../../low_treatment/domain/models/low_treatment_review_entry.dart';
import '../../../low_treatment/domain/use_cases/build_low_treatment_review_use_case.dart';
import '../../domain/models/day_analysis_window.dart';
import 'day_context_provider.dart';

final dayLowTreatmentReviewProvider = FutureProvider.autoDispose
    .family<List<LowTreatmentReviewEntry>, DateTime>((ref, date) async {
      final today = clock.now().toLocal();
      final context = ref.watch(
        (date == DateTime(today.year, today.month, today.day)
                ? dayContextProvider
                : dayContextForDateProvider(date))
            .future,
      );
      final repository = ref.watch(lowTreatmentReviewRepositoryProvider);
      final window = DayAnalysisWindow(now: clock.now(), date: date);
      final day = await context;
      if (day.carbEntries == null || day.lowTreatments == null) {
        throw StateError('Low treatment history unavailable');
      }
      final recorded = day.lowTreatments!;
      final decisions = day.carbEntries!.isEmpty
          ? <LowTreatmentReviewDecision>[]
          : await repository.fetch(window.start, window.queryEnd);
      return const BuildLowTreatmentReviewUseCase()(
        events: day.carbEntries!,
        recorded: recorded,
        decisions: decisions,
      );
    });

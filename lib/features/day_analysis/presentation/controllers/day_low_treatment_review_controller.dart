import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/treat.dart';
import '../../../low_treatment/data/providers/low_treatment_review_repository_provider.dart';
import '../../data/providers/day_context_provider.dart';
import '../../data/providers/day_low_treatment_review_provider.dart';

part 'day_low_treatment_review_controller.g.dart';

@riverpod
class DayLowTreatmentReviewController
    extends _$DayLowTreatmentReviewController {
  @override
  Future<void> build(DateTime date) async {}

  Future<void> resolve(
    Treat event, {
    int? mealId,
    bool dismissed = false,
    bool created = false,
  }) => _save(
    () => ref
        .read(lowTreatmentReviewRepositoryProvider)
        .save(event, mealId: mealId, dismissed: dismissed),
    created: created,
  );

  Future<void> reset(DateTime occurredAt) => _save(
    () => ref.read(lowTreatmentReviewRepositoryProvider).reset(occurredAt),
  );

  Future<void> _save(
    Future<void> Function() save, {
    bool created = false,
  }) async {
    if (state.isLoading) throw StateError('A review change is being saved');
    final keepAlive = ref.keepAlive();
    state = const AsyncLoading();
    try {
      await save();
      if (ref.mounted) state = const AsyncData(null);
    } catch (error, stack) {
      if (ref.mounted) state = AsyncError(error, stack);
      rethrow;
    } finally {
      if (ref.mounted) {
        ref.invalidate(dayLowTreatmentReviewProvider(date));
        if (created) {
          ref.invalidate(dayContextProvider);
          ref.invalidate(dayContextForDateProvider(date));
        }
      }
      keepAlive.close();
    }
  }
}

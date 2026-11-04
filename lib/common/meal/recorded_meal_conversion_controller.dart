import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'recorded_meal_conversion_request.dart';
import 'review_recorded_meal_conversion_use_case.dart';

part 'recorded_meal_conversion_controller.g.dart';

@riverpod
class RecordedMealConversionController
    extends _$RecordedMealConversionController {
  @override
  AsyncValue<void> build(int mealId) => const AsyncData(null);

  Future<List<RecordedMealConversionRequest>?> begin() async {
    if (state.isLoading) return null;
    state = const AsyncLoading();
    try {
      return await ref
          .read(reviewRecordedMealConversionUseCaseProvider)
          .load(mealId);
    } catch (error, stack) {
      if (ref.mounted) state = AsyncError(error, stack);
      return null;
    }
  }

  void cancel() {
    if (ref.mounted) state = const AsyncData(null);
  }

  Future<bool> confirm(
    Map<RecordedMealConversionRequest, double> reviewed,
  ) async {
    try {
      await ref
          .read(reviewRecordedMealConversionUseCaseProvider)
          .confirm(reviewed);
      if (!ref.mounted) return false;
      state = const AsyncData(null);
      return true;
    } catch (error, stack) {
      if (ref.mounted) state = AsyncError(error, stack);
      return false;
    }
  }
}

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/bolus_wizard.dart';
import '../../../../core/logger/logger.dart';
import '../../../meals/common/models/meal_wizard_relation_type.dart';
import '../../../meals/data/models/meal_review_timing.dart';
import '../../../meals/data/providers/confirm_reviewed_meal_use_case_provider.dart';
import '../../../meals/data/providers/meal_wizard_link_repository_provider.dart';
import '../../data/providers/day_context_provider.dart';
import '../../data/providers/day_meal_review_provider.dart';

part 'day_meal_review_controller.g.dart';

@riverpod
class DayMealReviewController extends _$DayMealReviewController {
  @override
  Future<void> build(DateTime date) async {}

  Future<void> link(
    BolusWizard wizard,
    int mealId,
    MealWizardRelationType type, {
    bool mealWasCreated = false,
    MealReviewTiming? timing,
  }) => _save(
    () => ref
        .read(confirmReviewedMealUseCaseProvider)
        .call(
          wizard: wizard,
          mealId: mealId,
          relationType: type,
          timing: timing,
        ),
    mealWasCreated: mealWasCreated,
  );

  Future<void> unlink(int id) => _save(() async {
    await ref.read(mealWizardLinkRepositoryProvider).unlink(id);
    return false;
  });

  void _refreshMeals() {
    ref.invalidate(dayMealCandidatesProvider(date));
    ref.invalidate(dayMealReviewProvider(date));
    ref.invalidate(dayContextForDateProvider(date));
    ref.invalidate(dayContextProvider);
  }

  Future<void> _save(
    Future<bool> Function() action, {
    bool mealWasCreated = false,
  }) async {
    if (state.isLoading) {
      throw StateError('A review change is already being saved');
    }
    final keepAlive = ref.keepAlive();
    state = const AsyncLoading();
    var mealChanged = mealWasCreated;
    var saved = false;
    try {
      mealChanged = await action() || mealChanged;
      saved = true;
      state = const AsyncData(null);
    } catch (error, stack) {
      Log.e(
        'DayMealReviewController',
        'Meal review save failed for day $date; mealWasCreated=$mealWasCreated',
        error: error,
        stackTrace: stack,
      );
      state = AsyncError(error, stack);
      rethrow;
    } finally {
      if (mealChanged) {
        _refreshMeals();
      } else if (saved) {
        ref.invalidate(dayMealReviewProvider(date));
      }
      keepAlive.close();
    }
  }
}

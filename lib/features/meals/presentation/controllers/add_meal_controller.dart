import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../common/l10n/language.dart';
import '../../../../core/domain/model/meal.dart';
import '../../data/domain/use_cases/add_meal_use_case.dart';
import '../../data/domain/use_cases/log_retrospective_meal_use_case.dart';
import '../../data/domain/use_cases/save_meal_draft_use_case.dart';
import '../../data/drafts/meal_draft.dart';
import '../../data/models/retrospective_meal_timing.dart';
import '../../data/providers/meal_draft_provider.dart';
import 'copy_meal_source_controller.dart';

part 'add_meal_controller.g.dart';

@riverpod
class AddMealControllerNotifier extends _$AddMealControllerNotifier {
  bool _isSaving = false;
  @override
  Future<Meal?> build() async {
    return null;
  }

  Future<Meal> addMeal(
    MealDraft draft, {
    RetrospectiveMealTiming? retrospective,
  }) async {
    return _persist(
      () => retrospective == null
          ? ref.read(addMealUseCaseProvider).call(draft)
          : LogRetrospectiveMealUseCase(ref).call(draft, retrospective),
    );
  }

  Future<Meal> saveCurrentDraft(
    AppLocalizations language, {
    RetrospectiveMealTiming? retrospective,
  }) {
    final draft = ref.read(mealDraftProvider);
    final automaticName = ref
        .read(mealDraftProvider.notifier)
        .usesAutomaticName;
    return _persist(
      () => SaveMealDraftUseCase(ref).call(
        draft,
        automaticName: automaticName,
        language: language,
        retrospective: retrospective,
      ),
    );
  }

  Future<Meal> _persist(Future<Meal> Function() save) async {
    if (ref.read(copyMealSourceControllerProvider).isLoading) {
      throw StateError('Cannot save a meal while its source is loading');
    }
    if (_isSaving) throw StateError('A meal save is already in progress');
    _isSaving = true;
    final keepAliveLink = ref.keepAlive();
    state = const AsyncLoading();
    try {
      final meal = await save();
      state = AsyncData(meal);
      return meal;
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    } finally {
      _isSaving = false;
      keepAliveLink.close();
    }
  }
}

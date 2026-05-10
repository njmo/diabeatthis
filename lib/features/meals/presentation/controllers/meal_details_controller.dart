import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/domain/use_cases/analyze_meal_use_case.dart';
import '../../data/domain/use_cases/load_meal_details_use_case.dart';
import '../models/meal_page_state.dart';

part 'meal_details_controller.g.dart';

@riverpod
class MealDetailsControllerNotifier extends _$MealDetailsControllerNotifier {
  @override
  Future<MealPageState> build(int mealId) async {
    final detailsUseCase = ref.read(loadMealDetailsUseCaseProvider);
    final details = await detailsUseCase.call(mealId);

    final analysisUseCase = ref.read(analyzeMealUseCaseProvider);
    try {
      final analysis = await analysisUseCase.call(details);
      return MealPageState(details: details, analysis: analysis);
    } catch (error) {
      return MealPageState(details: details, analysisError: error.toString());
    }
  }

  void setDetailedMode(bool value) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(detailedMode: value));
  }

  void setShowRawTechnicalData(bool value) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(showRawTechnicalData: value));
  }
}

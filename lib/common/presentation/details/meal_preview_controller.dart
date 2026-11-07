import '../../../features/meals/presentation/models/meal_page_state.dart';

abstract interface class MealPreviewController {
  MealPageState get state;
  bool get canUseLocalActions;
  bool get showAnalysis;
}

class PatientMealPreviewController implements MealPreviewController {
  const PatientMealPreviewController(this.state);
  @override
  final MealPageState state;
  @override
  bool get canUseLocalActions => true;
  @override
  bool get showAnalysis => true;
}

class CaregiverMealPreviewController implements MealPreviewController {
  const CaregiverMealPreviewController(this.state);
  @override
  final MealPageState state;
  @override
  bool get canUseLocalActions => false;
  @override
  bool get showAnalysis => false;
}

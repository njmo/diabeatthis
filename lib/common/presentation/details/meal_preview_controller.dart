import '../../../features/meals/presentation/models/meal_page_state.dart';

abstract interface class MealPreviewController {
  MealPageState get state;
  bool get canUseLocalActions;
  bool get showAnalysis;
  void Function(int id)? get onOpenIngredient;
}

class PatientMealPreviewController implements MealPreviewController {
  const PatientMealPreviewController(this.state);
  @override
  final MealPageState state;
  @override
  bool get canUseLocalActions => true;
  @override
  bool get showAnalysis => true;
  @override
  void Function(int id)? get onOpenIngredient => null;
}

class CaregiverMealPreviewController implements MealPreviewController {
  const CaregiverMealPreviewController(
    this.state, {
    this.onOpenIngredient,
    this.showAnalysis = false,
  });
  @override
  final MealPageState state;
  @override
  bool get canUseLocalActions => false;
  @override
  final bool showAnalysis;
  @override
  final void Function(int id)? onOpenIngredient;
}

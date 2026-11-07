import '../../../features/ingredients/data/models/ingredient_details_data.dart';

abstract interface class IngredientPreviewController {
  IngredientDetailsData get data;
  void openMeal(int id);
  bool get showUsages;
  bool get showHistory;
  bool get showConfidence;
  bool get showPortions;
}

class PatientIngredientPreviewController
    implements IngredientPreviewController {
  const PatientIngredientPreviewController(this.data, this.onOpenMeal);
  @override
  final IngredientDetailsData data;
  final void Function(int id) onOpenMeal;
  @override
  void openMeal(int id) => onOpenMeal(id);
  @override
  bool get showUsages => true;
  @override
  bool get showHistory => true;
  @override
  bool get showConfidence => true;
  @override
  bool get showPortions => true;
}

class CaregiverIngredientPreviewController
    implements IngredientPreviewController {
  const CaregiverIngredientPreviewController(
    this.data, {
    required this.onOpenMeal,
    this.showUsages = true,
    this.showHistory = true,
    this.showConfidence = true,
    this.showPortions = true,
  });
  @override
  final IngredientDetailsData data;
  final void Function(int id) onOpenMeal;
  @override
  void openMeal(int id) => onOpenMeal(id);
  @override
  final bool showUsages;
  @override
  final bool showHistory;
  @override
  final bool showConfidence;
  @override
  final bool showPortions;
}

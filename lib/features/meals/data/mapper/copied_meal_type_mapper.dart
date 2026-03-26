import '../../../../core/drift/database_impl.dart';
import '../model/copied_meal_type.dart';

extension PortionDataToCopiedMealTemplateType on MealTemplateData {
  CopiedMealType toCopiedMealType() {
    return CopiedMealFromTemplate(
      id: id,
      name: name,
      date: DateTime.fromMillisecondsSinceEpoch(updatedAt),
      copiedFromMealId: createdFromMealId,
    );
  }
}

extension PortionDataToCopiedMealType on MealData {
  CopiedMealType toCopiedMealType() {
    return CopiedMealFromMeal(
      id: id,
      name: name,
      date: DateTime.fromMillisecondsSinceEpoch(updatedAt),
      copiedFromMealId: basedOnMealId,
      copiedFromTemplateId: mealTemplateId,
    );
  }
}

import '../../core/domain/model/meal.dart';
import 'language.dart';

String mealEntryLabel({
  required MealPurpose purpose,
  required String name,
  required AppLocalizations lang,
}) => switch (purpose) {
  MealPurpose.lowTreatment => lang.lowTreatmentMealName,
  MealPurpose.meal => name,
};

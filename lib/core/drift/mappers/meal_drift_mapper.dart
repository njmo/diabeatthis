import 'package:drift/drift.dart' as d;

import '../../../common/meal/meal_category.dart';
import '../../domain/model/meal.dart';
import '../entity/meal.dart';

extension MealDataToDomain on MealData {
  Meal toDomain() => Meal(
    id: id,
    name: name,
    category: MealCategory.fromStorage(category),
    status: status,
    purpose: MealPurpose.fromStorage(purpose),
    plannedAt: DateTime.fromMillisecondsSinceEpoch(plannedAt),
    createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt),
    mealTemplateId: mealTemplateId,
  );
}

extension MealDataIterableToDomain on Iterable<MealData> {
  List<Meal> toDomainList() => map((e) => e.toDomain()).toList();
}

extension DomainMealToCompanion on Meal {
  MealCompanion toCompanion() {
    return MealCompanion(
      id: d.Value(id),
      name: d.Value(purpose == MealPurpose.lowTreatment ? '' : name),
      category: d.Value(category?.name),
      plannedAt: d.Value(plannedAt!.millisecondsSinceEpoch),
      purpose: d.Value(purpose.storageValue),
      mealTemplateId: d.Value(mealTemplateId),
    );
  }
}

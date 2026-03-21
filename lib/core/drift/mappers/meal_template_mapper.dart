import 'package:drift/drift.dart' as d;

import '../../domain/model/meal_template.dart';
import '../entity/meal_template.dart';

extension MealTemplateDataToDomain on MealTemplateData {
  MealTemplate toDomain() => MealTemplate(
    id: id,
    name: name,
    notes: notes,
    createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt),
    createdFromMealId: createdFromMealId,
    isFavorite: isFavorite,
    isSynced: isSynced,
  );
}

extension MealTemplateDataIterableToDomain on Iterable<MealTemplateData> {
  List<MealTemplate> toDomainList() => map((e) => e.toDomain()).toList();
}

extension DomainMealTemplateToCompanion on MealTemplate {
  MealTemplateCompanion toCompanion() {
    return  MealTemplateCompanion(
        id: d.Value(id),
        name: d.Value(name),
        notes: notes == null ? d.Value.absent() : d.Value(notes),
        createdAt: d.Value(createdAt.millisecondsSinceEpoch),
        updatedAt: d.Value(updatedAt.millisecondsSinceEpoch),
        isFavorite: d.Value(isFavorite),
        createdFromMealId: createdFromMealId == null
            ? d.Value.absent()
            : d.Value(createdFromMealId),
        isSynced: d.Value(isSynced),
      );
  }
}

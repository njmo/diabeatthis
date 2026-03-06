import 'package:drift/drift.dart' as d;

import '../../domain/model/meal_template.dart';
import '../entity/meal_template.dart';

extension MealDataToDomain on MealTemplateData {
  MealTemplate toDomain() => MealTemplate.existing(
    id: id,
    name: name,
    notes: notes,
    createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt),
    isFavorite: isFavorite,
    isSynced: isSynced,
  );
}

extension MealDataIterableToDomain on Iterable<MealTemplateData> {
  List<MealTemplate> toDomainList() => map((e) => e.toDomain()).toList();
}

extension DomainMealToCompanion on MealTemplate {
  MealTemplateCompanion toCompanion() {
    return map(
      existing: (e) => MealTemplateCompanion(
        id: d.Value(e.id),
        name: d.Value(e.name),
        notes: e.notes == null ? d.Value.absent() : d.Value(e.notes),
        createdAt: d.Value(e.createdAt.millisecondsSinceEpoch),
        updatedAt: d.Value(e.updatedAt.millisecondsSinceEpoch),
        isFavorite: d.Value(e.isFavorite),
        createdFromMealId: e.createdFromMealId == null
            ? d.Value.absent()
            : d.Value(e.createdFromMealId),
        isSynced: d.Value(e.isSynced),
      ),
      view: (_) => throw Exception('Cannot convert view to companion'),
      draft: (e) => MealTemplateCompanion(
        id: d.Value.absent(),
        name: d.Value(e.name),
        notes: e.notes == null ? d.Value.absent() : d.Value(e.notes),
        isFavorite: d.Value(e.isFavorite),
        createdFromMealId: e.createdFromMealId == null
            ? d.Value.absent()
            : d.Value(e.createdFromMealId),
      ),
      empty: (_) => throw Exception('Cannot convert empty to companion'),
    );
  }
}

import 'package:drift/drift.dart' as d;

import '../../domain/model/meal.dart';
import '../entity/meal.dart';

extension MealDataToDomain on MealData {
  Meal toDomain() => Meal(
    id: id,
    name: name,
    status: status,
    plannedAt: DateTime.fromMillisecondsSinceEpoch(plannedAt),
    createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt),
  );
}

extension MealDataIterableToDomain on Iterable<MealData> {
  List<Meal> toDomainList() => map((e) => e.toDomain()).toList();
}

extension DomainMealToCompanion on Meal {
  MealCompanion toCompanion() {
    return MealCompanion(
      id: d.Value(id),
      name: d.Value(name),
      plannedAt: d.Value(plannedAt!.millisecondsSinceEpoch),
    );
  }
}

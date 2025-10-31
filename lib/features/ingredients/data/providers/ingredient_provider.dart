
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/ingredient.dart' as domain;
import '../../../../core/drift/mappers/ingredient_drift_mapper.dart';

import '../../../../core/drift/mappers/portion_drift_mapper.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../data/drafts/ingredient_draft.dart';

part 'ingredient_provider.g.dart';

@riverpod
Stream<List<domain.Ingredient>> ingredientsStream(Ref ref) {
  final db = ref.watch(databaseProvider);
  return db.ingredientDao.getAllIngredients().watch().map(
    (e) => e.toDomainList(),
  );
}

@riverpod
Future<List<domain.Ingredient>> ingredientsByQuery(
  Ref ref,
  String query,
) async {
  final db = ref.watch(databaseProvider);
  final ing = await db.ingredientDao.searchIngredientsByName(query).get();
  return ing.map((e) => e.toDomain()).toList();
}

@riverpod
Future<void> insertIngredient(Ref ref, domain.Ingredient ingredient) async {
  final db = ref.watch(databaseProvider);
  await db.into(db.ingredient).insert(ingredient.toCompanion());
}

@riverpod
class IngredientDraftNotifier extends _$IngredientDraftNotifier {
  @override
  IngredientSelection build() {
    return IngredientSelection.draft(
      name: '',
      carbsPer100g: 0,
      fatPer100g: 0,
      fiberPer100g: 0,
      proteinPer100g: 0,
    );
  }

  void setCarbsPer100g(String value) =>
      state = state.copyWith(carbsPer100g: double.tryParse(value) ?? 0.0);
  void setFatPer100g(String value) =>
      state = state.copyWith(fatPer100g: double.tryParse(value) ?? 0.0);
  void setFiberPer100g(String value) =>
      state = state.copyWith(fiberPer100g: double.tryParse(value) ?? 0.0);
  void setProteinPer100g(String value) =>
      state = state.copyWith(proteinPer100g: double.tryParse(value) ?? 0.0);
  void setName(String value) => state = state.copyWith(name: value);
}

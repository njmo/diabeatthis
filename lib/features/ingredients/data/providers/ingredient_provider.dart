import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/ingredient.dart' as domain;
import '../../../../core/domain/model/portion.dart' as domain;
import '../../../../core/drift/mappers/ingredient_drift_mapper.dart';

import '../../../../core/drift/providers/database_provider.dart';
import '../../data/drafts/ingredient_draft.dart';
import '../mappers/ingredient_draft_mapper.dart';

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
  final ing = await db.ingredientDao.searchIngredientsByName(query, 6).get();
  return ing.map((e) => e.toDomain()).toList();
}

@riverpod
class IngredientPortionAmountDraftNotifier
    extends _$IngredientPortionAmountDraftNotifier {
  @override
  int build() {
    return 0;
  }

  void setAmount(String amount) => state = int.tryParse(amount) ?? 0;
}

@riverpod
Future<domain.Ingredient> insertIngredient(
  Ref ref,
  IngredientSelection ingredient,
) async {
  return ingredient.map(
    draft: (draft) async {
      final db = ref.watch(databaseProvider);
      final value = await db
          .into(db.ingredient)
          .insertReturningOrNull(ingredient.toCompanion());
      if (value != null) {
        return value.toDomain();
      } else {
        throw Exception('Could not insert ingredient');
      }
    },
    existing: (existing) => existing.toDomain(),
  );
}

@riverpod
Future<void> insertIngredientPortion(
  Ref ref,
  domain.Ingredient ingredient,
  domain.Portion? portion,
  int amount,
) async {
  if (portion == null) {
    return;
  }
  final db = ref.watch(databaseProvider);
  await db.insertIngredientPortion(ingredient.id, portion.id, amount);
}

@riverpod
Future<int?> getAmountForPortionIngredient(
  Ref ref,
  domain.Ingredient ingredient,
  domain.Portion portion,
) async {
  final db = ref.watch(databaseProvider);
  return await db
      .amountIngredientPortion(ingredient.id, portion.id)
      .getSingleOrNull();
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
  void overrideDraft(IngredientSelection ingredient) => state = ingredient;

  String getName() => state.map(draft: (d) => d.name, existing: (e) => e.name);
  String getCarbsPer100g() => state
      .map(draft: (d) => d.carbsPer100g, existing: (e) => e.carbsPer100g)
      .toStringAsFixed(0);

  String getFatPer100g() => state
      .map(draft: (d) => d.fatPer100g, existing: (e) => e.fatPer100g)
      .toStringAsFixed(0);

  String getFiberPer100g() => state
      .map(draft: (d) => d.fiberPer100g, existing: (e) => e.fiberPer100g)
      .toStringAsFixed(0);

  String getProteinPer100g() => state
      .map(draft: (d) => d.proteinPer100g, existing: (e) => e.proteinPer100g)
      .toStringAsFixed(0);
}

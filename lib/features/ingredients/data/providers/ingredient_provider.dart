import 'package:flutter_riverpod/flutter_riverpod.dart' show FutureProvider;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/ingredient.dart' as domain;
import '../../../../core/domain/model/portion.dart' as domain;
import '../../../../core/drift/mappers/ingredient_drift_mapper.dart';

import '../../../../core/drift/providers/database_provider.dart';
import '../../../meals/presentation/widgets/confidence_slider.dart';

part 'ingredient_provider.g.dart';

const ingredientListPageSize = 15;

@riverpod
Stream<List<domain.Ingredient>> ingredientsStream(Ref ref) {
  final db = ref.watch(databaseProvider);
  return db.ingredientDao.getAllIngredients().watch().map(
    (e) => e.toDomainList(),
  );
}

final ingredientListPageProvider = FutureProvider.autoDispose
    .family<List<domain.Ingredient>, int>((ref, page) async {
      final db = ref.watch(databaseProvider);
      final ingredients = await db.ingredientDao.getIngredientsPage(page: page);
      return ingredients.toDomainList();
    });

@riverpod
Future<domain.Ingredient> ingredientById(Ref ref, int id) async {
  final db = ref.watch(databaseProvider);
  final ing = await db.ingredientDao.getIngredientById(id);
  return ing.toDomain();
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
  double build() {
    return 0;
  }

  void setAmount(String amount) => state = double.tryParse(amount) ?? 0;
}

@riverpod
Future<domain.Ingredient> insertIngredient(
  Ref ref,
  domain.Ingredient ingredient,
) async {
  return ingredient.map(
    draft: (draft) async {
      final name = draft.name.trim();
      if (name.isEmpty) {
        throw ArgumentError('Ingredient name cannot be empty');
      }

      final db = ref.watch(databaseProvider);
      final value = await db
          .into(db.ingredient)
          .insertReturningOrNull(draft.copyWith(name: name).toCompanion());
      if (value != null) {
        return value.toDomain();
      } else {
        throw Exception('Could not insert ingredient');
      }
    },
    existing: (existing) => existing,
  );
}

@riverpod
Future<void> insertIngredientPortion(
  Ref ref,
  domain.Ingredient ingredient,
  domain.Portion? portion,
  double amount,
) async {
  if (portion == null) {
    return;
  }
  final db = ref.watch(databaseProvider);
  final ingredientId = ingredient.map(
    existing: (e) => e.id,
    draft: (_) => throw Exception('Cannot get id for draft'),
  );
  await db.insertIngredientPortion(ingredientId, portion.id, amount);
}

@riverpod
Future<double?> getAmountForPortionIngredient(
  Ref ref,
  domain.Ingredient ingredient,
  domain.Portion portion,
) async {
  final db = ref.watch(databaseProvider);
  final ingredientId = ingredient.map(
    existing: (e) => e.id,
    draft: (_) => throw Exception('Cannot get id for draft'),
  );
  return await db
      .amountIngredientPortion(ingredientId, portion.id)
      .getSingleOrNull();
}

@riverpod
class IngredientDraftNotifier extends _$IngredientDraftNotifier {
  @override
  domain.Ingredient build() {
    return domain.Ingredient.draft(
      name: '',
      carbsPer100g: 0,
      fatPer100g: 0,
      fiberPer100g: 0,
      proteinPer100g: 0,
      nutritionConfidence: 0.25,
      isReference: false,
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
  void setNutritionConfidence(ConfidenceLevel value) =>
      state = state.copyWith(nutritionConfidence: value.toDouble01());
  void overrideDraft(domain.Ingredient ingredient) => state = ingredient;

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

  ConfidenceLevel getNutritionConfidence() => state.map(
    draft: (d) => ConfidenceLevelX.fromDouble01(d.nutritionConfidence),
    existing: (e) => e.nutritionConfidence as ConfidenceLevel,
  );

  String? getBrand() =>
      state.map(draft: (d) => d.brand, existing: (e) => e.brand);
  void setBrand(String value) => state = state.copyWith(brand: value);

  void setIsReference(bool value) => state = state.copyWith(isReference: value);
}

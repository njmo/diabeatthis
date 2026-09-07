import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../common/nutrition/confidence_level.dart';
import '../../../../common/utils/normalize_optional_text.dart';
import '../../../../core/domain/model/carbs_label_mode.dart';
import '../../../../core/domain/model/ingredient.dart' as domain;
import '../../../../core/domain/model/portion.dart' as domain;
import '../../../../core/drift/mappers/ingredient_drift_mapper.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../../meal_advisor/data/models/ingredient_photo_search_result.dart';
import '../drafts/ingredient_draft.dart';
import '../persistence/insert_ingredient_draft.dart';

part 'ingredient_provider.g.dart';

const ingredientListPageSize = 10;

@riverpod
Stream<List<domain.Ingredient>> ingredientsStream(Ref ref) {
  final db = ref.watch(databaseProvider);
  return db.ingredientDao.getAllIngredients().watch().map(
    (e) => e.toDomainList(),
  );
}

@riverpod
Stream<List<domain.Ingredient>> ingredientListStream(Ref ref) {
  final db = ref.watch(databaseProvider);
  return db.ingredientDao.watchIngredients().map(
    (ingredients) => ingredients.toDomainList(),
  );
}

@riverpod
Future<List<domain.Ingredient>> latestIngredients(Ref ref) async {
  final db = ref.watch(databaseProvider);
  final ingredients = await db.ingredientDao.getLatestIngredients(limit: 10);
  return ingredients.toDomainList();
}

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
  final ing = await db.ingredientDao.searchIngredientsByQuery(
    queryString: query,
    limit: 6,
  );
  return ing.map((e) => e.toDomain()).toList();
}

@riverpod
Stream<List<domain.Ingredient>> ingredientsByQueryStream(
  Ref ref,
  String query,
) {
  final db = ref.watch(databaseProvider);
  return db.ingredientDao
      .watchIngredientsByQuery(queryString: query, limit: 10)
      .map((ingredients) => ingredients.toDomainList());
}

@riverpod
Future<List<domain.Ingredient>> ingredientsByPhotoSearchCandidates(
  Ref ref,
  String candidatesKey,
) async {
  final candidates = IngredientPhotoSearchResult.tryParseCandidatesKey(
    candidatesKey,
  );
  if (candidates == null || !candidates.hasCandidates) {
    return const [];
  }

  final db = ref.watch(databaseProvider);
  final rows = await db.ingredientDao.searchIngredientsByNamesOrBrand(
    names: candidates.names,
    brand: candidates.brand,
    limit: 12,
  );

  return rows.toDomainList();
}

@riverpod
class IngredientPortionAmountDraftNotifier
    extends _$IngredientPortionAmountDraftNotifier {
  @override
  double build() {
    return 0;
  }

  void setAmount(String amount) => state = double.tryParse(amount) ?? 0;
  void setValue(double amount) => state = amount < 0 ? 0 : amount;
}

@riverpod
Future<domain.Ingredient> insertIngredient(
  Ref ref,
  IngredientDraft ingredient,
) async {
  return insertIngredientDraft(ref.watch(databaseProvider), ingredient);
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
  await db.insertIngredientPortion(ingredient.id, portion.id, amount);
}

@riverpod
Future<double?> getAmountForPortionIngredient(
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
  IngredientDraft build() {
    return IngredientDraft.draft(
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
      state = state.copyWith(carbsPer100g: _parseDraftNumber(value));
  void setFatPer100g(String value) =>
      state = state.copyWith(fatPer100g: _parseDraftNumber(value));
  void setFiberPer100g(String value) =>
      state = state.copyWith(fiberPer100g: _parseDraftNumber(value));
  void setProteinPer100g(String value) =>
      state = state.copyWith(proteinPer100g: _parseDraftNumber(value));
  void setCarbsLabelMode(CarbsLabelMode value) {
    state = state.map(
      draft: (draft) => draft.copyWith(carbsLabelMode: value),
      existing: (existing) => existing,
    );
  }

  void setName(String value) => state = state.copyWith(name: value);
  void setNutritionConfidence(ConfidenceLevel value) =>
      state = state.copyWith(nutritionConfidence: value.toDouble01());
  void overrideDraft(IngredientDraft ingredient) => state = ingredient;

  String getName() => state.map(draft: (d) => d.name, existing: (e) => e.name);

  String? getBrand() =>
      state.map(draft: (d) => d.brand, existing: (e) => e.brand);
  void setBrand(String value) =>
      state = state.copyWith(brand: normalizeOptionalText(value));

  void setBarcode(String value) {
    final normalized = value.trim();
    state = state.copyWith(barcode: normalized.isEmpty ? null : normalized);
  }

  void setIsReference(bool value) {
    state = state.copyWith(
      isReference: value,
      barcode: value ? null : state.barcode,
    );
  }
}

double _parseDraftNumber(String value) {
  final normalized = value.trim().replaceAll(',', '.');
  return double.tryParse(normalized) ?? 0.0;
}

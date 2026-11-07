import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/domain/model/carbs_label_mode.dart';
import '../../../../../core/domain/model/ingredient.dart' as domain;
import '../../../../../core/drift/database_impl.dart';
import '../../../../../core/drift/mappers/ingredient_drift_mapper.dart';
import '../../../../../core/drift/providers/database_provider.dart';
import '../../../../../core/logger/logger.dart';
import '../../../domain/services/ingredient_matcher.dart';
import '../../../domain/utils/ingredient_barcode_validator.dart';
import '../../models/ingredient_scan_result.dart';
import 'find_ingredient_by_barcode_use_case.dart';

part 'find_matching_ingredient_for_scan_result_use_case.g.dart';

@riverpod
FindMatchingIngredientForScanResultUseCase
findMatchingIngredientForScanResultUseCase(Ref ref) {
  return FindMatchingIngredientForScanResultUseCase(
    db: ref.watch(databaseProvider),
    findIngredientByBarcode: ref.watch(findIngredientByBarcodeUseCaseProvider),
    matcher: const IngredientMatcher(),
  );
}

class FindMatchingIngredientForScanResultUseCase with Logging {
  static const _barcodeValidator = IngredientBarcodeValidator();

  final DatabaseImpl db;
  final FindIngredientByBarcodeUseCase findIngredientByBarcode;
  final IngredientMatcher matcher;

  const FindMatchingIngredientForScanResultUseCase({
    required this.db,
    required this.findIngredientByBarcode,
    required this.matcher,
  });

  Future<domain.Ingredient?> call(IngredientScanResult result) =>
      find(result, persistBarcode: true);

  Future<domain.Ingredient?> callReadOnly(IngredientScanResult result) =>
      find(result, persistBarcode: false);

  Future<domain.Ingredient?> find(
    IngredientScanResult result, {
    required bool persistBarcode,
  }) async {
    final barcode = _barcodeValidator.normalizeValidBarcode(
      result.barcode ?? '',
    );
    if (barcode != null) {
      final ingredient = await findIngredientByBarcode.call(barcode);
      if (ingredient != null) {
        return ingredient;
      }
    }

    final name = result.name?.trim();
    if (name == null || name.isEmpty) {
      return null;
    }

    final rows = await db.ingredientDao.searchIngredientsByNamesOrBrand(
      names: [name],
      brand: result.brand,
      limit: 20,
    );
    if (!persistBarcode) {
      final nutrition = result.nutritionPer100g;
      if (!(nutrition?.hasCompleteMacros ?? false)) return null;
      String normalized(String? value) => value?.trim().toLowerCase() ?? '';
      final matches = rows
          .toDomainList()
          .where(
            (ingredient) =>
                !ingredient.isReference &&
                normalized(ingredient.name) == normalized(name) &&
                normalized(ingredient.brand) == normalized(result.brand) &&
                compatibleBarcode(ingredient, barcode) != null &&
                ingredient.carbsLabelMode == CarbsLabelMode.eu &&
                ingredient.carbsPer100g == nutrition!.carbs &&
                ingredient.fiberPer100g == nutrition.fiber &&
                ingredient.fatPer100g == nutrition.fat &&
                ingredient.proteinPer100g == nutrition.protein,
          )
          .toList();
      return matches.length == 1 ? matches.single : null;
    }
    final quickMatch = matcher.findByNameAndBrand(
      candidates: rows.toDomainList(),
      name: name,
      brand: result.brand,
    );
    if (quickMatch != null) {
      return _saveBarcodeIfMissing(quickMatch, barcode);
    }

    final allRows = await db.ingredientDao.getAllIngredients().get();
    final fullMatch = matcher.findByNameAndBrand(
      candidates: allRows.toDomainList(),
      name: name,
      brand: result.brand,
    );
    return _saveBarcodeIfMissing(fullMatch, barcode);
  }

  domain.Ingredient? compatibleBarcode(
    domain.Ingredient? ingredient,
    String? barcode,
  ) {
    final current = ingredient?.barcode?.trim();
    return current != null && current.isNotEmpty && current != barcode
        ? null
        : ingredient;
  }

  Future<domain.Ingredient?> _saveBarcodeIfMissing(
    domain.Ingredient? ingredient,
    String? barcode,
  ) async {
    if (ingredient == null ||
        barcode == null ||
        (ingredient.barcode?.trim().isNotEmpty ?? false)) {
      return ingredient;
    }

    try {
      await db.ingredientDao.updateIngredientBarcodeIfMissing(
        ingredientId: ingredient.id,
        barcode: barcode,
      );
      return ingredient.copyWith(barcode: barcode);
    } catch (error) {
      logW(
        'Saving matched ingredient barcode failed for ingredient ${ingredient.id}. error=$error',
      );
      return ingredient;
    }
  }
}

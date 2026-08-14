import 'package:riverpod_annotation/riverpod_annotation.dart';

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

  Future<domain.Ingredient?> call(IngredientScanResult result) async {
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

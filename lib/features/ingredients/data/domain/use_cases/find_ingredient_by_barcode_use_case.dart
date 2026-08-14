import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../../core/domain/model/ingredient.dart' as domain;
import '../../../../../core/drift/database_impl.dart';
import '../../../../../core/drift/mappers/ingredient_drift_mapper.dart';
import '../../../../../core/drift/providers/database_provider.dart';
import '../../../domain/utils/ingredient_barcode_validator.dart';

part 'find_ingredient_by_barcode_use_case.g.dart';

@riverpod
FindIngredientByBarcodeUseCase findIngredientByBarcodeUseCase(Ref ref) {
  return FindIngredientByBarcodeUseCase(db: ref.watch(databaseProvider));
}

class FindIngredientByBarcodeUseCase {
  static const _barcodeValidator = IngredientBarcodeValidator();

  final DatabaseImpl db;

  const FindIngredientByBarcodeUseCase({required this.db});

  Future<domain.Ingredient?> call(String barcode) async {
    final normalizedBarcode = _barcodeValidator.normalizeValidBarcode(barcode);
    if (normalizedBarcode == null) {
      return null;
    }

    final ingredient = await db.ingredientDao
        .getIngredientByBarcode(normalizedBarcode)
        .getSingleOrNull();
    return ingredient?.toDomain();
  }
}

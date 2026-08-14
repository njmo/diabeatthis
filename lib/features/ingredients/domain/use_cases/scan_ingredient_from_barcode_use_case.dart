import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/clients/open_food_facts_product_client.dart';
import '../../data/mappers/open_food_facts_product_mapper.dart';
import '../../data/models/ingredient_scan_result.dart';
import '../../data/providers/open_food_facts_product_client_provider.dart';
import '../services/ingredient_scan_result_validator.dart';
import '../utils/ingredient_barcode_validator.dart';

part 'scan_ingredient_from_barcode_use_case.g.dart';

@riverpod
ScanIngredientFromBarcodeUseCase scanIngredientFromBarcodeUseCase(Ref ref) {
  return ScanIngredientFromBarcodeUseCase(
    client: ref.watch(openFoodFactsProductClientProvider),
    mapper: const OpenFoodFactsProductMapper(),
    validator: const IngredientScanResultValidator(),
  );
}

class ScanIngredientFromBarcodeUseCase {
  static const _barcodeValidator = IngredientBarcodeValidator();

  final OpenFoodFactsProductClient client;
  final OpenFoodFactsProductMapper mapper;
  final IngredientScanResultValidator validator;

  const ScanIngredientFromBarcodeUseCase({
    required this.client,
    required this.mapper,
    required this.validator,
  });

  Future<IngredientScanResult> call(String barcode) async {
    final normalizedBarcode = _barcodeValidator.normalizeValidBarcode(barcode);
    if (normalizedBarcode == null) {
      throw FormatException('Invalid barcode: $barcode');
    }

    final response = await client.fetchProduct(normalizedBarcode);
    return validator.validate(mapper.map(normalizedBarcode, response));
  }
}

import '../clients/open_food_facts_product_client.dart';
import '../models/ingredient_scan_result.dart';

class OpenFoodFactsProductMapper {
  const OpenFoodFactsProductMapper();

  IngredientScanResult map(String barcode, Map<String, dynamic> json) {
    final status = json['status'];
    final product = json['product'];
    if (status != 1 || product is! Map<String, dynamic>) {
      throw OpenFoodFactsProductNotFoundException(barcode);
    }

    final nutriments = product['nutriments'];
    final nutritionPer100g = nutriments is Map<String, dynamic>
        ? NutritionPer100g(
            carbs: readNonNegativeNumber(nutriments, 'carbohydrates_100g'),
            fat: readNonNegativeNumber(nutriments, 'fat_100g'),
            protein: readNonNegativeNumber(nutriments, 'proteins_100g'),
            fiber: readNonNegativeNumber(nutriments, 'fiber_100g'),
          )
        : const NutritionPer100g(
            carbs: null,
            fat: null,
            protein: null,
            fiber: null,
          );

    return IngredientScanResult(
      status: IngredientScanStatus.recognized,
      name: readProductName(product),
      brand: readBrand(product),
      barcode: barcode,
      nutritionPer100g: nutritionPer100g,
      portions: readPortions(product),
      retakeRequest: null,
    );
  }

  String? readProductName(Map<String, dynamic> product) {
    return readString(product, 'product_name_pl') ??
        readString(product, 'product_name') ??
        readString(product, 'generic_name_pl') ??
        readString(product, 'generic_name');
  }

  String? readBrand(Map<String, dynamic> product) {
    final brandsTags = product['brands_tags'];
    if (brandsTags is List) {
      for (final brand in brandsTags.whereType<String>()) {
        final normalized = brand.trim().replaceAll('-', ' ');
        if (normalized.isNotEmpty) {
          return normalized;
        }
      }
    }

    final brands = readString(product, 'brands');
    final brand = brands
        ?.split(',')
        .map((brand) => brand.trim())
        .firstWhere((brand) => brand.isNotEmpty, orElse: () => '');
    return brand == null || brand.isEmpty ? null : brand;
  }

  List<RecognizedPortion> readPortions(Map<String, dynamic> product) {
    final grams = readPositiveNumber(product, 'serving_quantity');
    if (grams == null) {
      return const [];
    }

    return [
      RecognizedPortion(
        name: readString(product, 'serving_size') ?? 'Porcja',
        unitHint: 'porcja',
        grams: grams,
        source: 'open_food_facts',
      ),
    ];
  }

  String? readString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return null;
  }

  double? readNonNegativeNumber(Map<String, dynamic> json, String key) {
    final value = parseNumber(json[key]);
    if (value == null || value < 0) {
      return null;
    }
    return value;
  }

  double? readPositiveNumber(Map<String, dynamic> json, String key) {
    final value = parseNumber(json[key]);
    if (value == null || value <= 0) {
      return null;
    }
    return value;
  }

  double? parseNumber(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is! String) {
      return null;
    }

    final normalized = value.trim().replaceAll(',', '.');
    final match = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(normalized);
    if (match == null) {
      return null;
    }
    return double.tryParse(match.group(0)!);
  }
}

import 'dart:convert';

import 'package:diabeatthis/features/ingredients/data/clients/open_food_facts_product_client.dart';
import 'package:diabeatthis/features/ingredients/data/mappers/open_food_facts_product_mapper.dart';
import 'package:diabeatthis/features/ingredients/data/models/ingredient_scan_result.dart';
import 'package:diabeatthis/features/ingredients/domain/services/ingredient_scan_result_validator.dart';
import 'package:diabeatthis/features/ingredients/domain/use_cases/scan_ingredient_from_barcode_use_case.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('ScanIngredientFromBarcodeUseCase', () {
    test(
      'returns needsReview when Open Food Facts has incomplete macros',
      () async {
        final useCase = ScanIngredientFromBarcodeUseCase(
          client: OpenFoodFactsProductClient(
            httpClient: MockClient((request) async {
              return http.Response(
                jsonEncode({
                  'status': 1,
                  'product': {
                    'product_name': 'Test product',
                    'nutriments': {'carbohydrates_100g': 12.5},
                  },
                }),
                200,
              );
            }),
          ),
          mapper: const OpenFoodFactsProductMapper(),
          validator: const IngredientScanResultValidator(),
        );

        final result = await useCase.call('5449000000996');

        expect(result.status, IngredientScanStatus.needsReview);
        expect(result.name, 'Test product');
        expect(result.nutritionPer100g?.carbs, 12.5);
      },
    );

    test('rejects non-numeric barcode', () async {
      final useCase = ScanIngredientFromBarcodeUseCase(
        client: OpenFoodFactsProductClient(
          httpClient: MockClient((request) async => http.Response('{}', 200)),
        ),
        mapper: const OpenFoodFactsProductMapper(),
        validator: const IngredientScanResultValidator(),
      );

      expect(() => useCase.call('abc'), throwsA(isA<FormatException>()));
    });

    test('rejects barcode with invalid check digit', () async {
      final useCase = ScanIngredientFromBarcodeUseCase(
        client: OpenFoodFactsProductClient(
          httpClient: MockClient((request) async => http.Response('{}', 200)),
        ),
        mapper: const OpenFoodFactsProductMapper(),
        validator: const IngredientScanResultValidator(),
      );

      expect(
        () => useCase.call('5900512350081'),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

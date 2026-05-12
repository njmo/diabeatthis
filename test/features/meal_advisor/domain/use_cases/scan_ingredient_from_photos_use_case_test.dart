import 'package:diabeatthis/core/logger/logger.dart';
import 'package:diabeatthis/features/meal_advisor/data/clients/debug_ingredient_photo_scan_client.dart';
import 'package:diabeatthis/features/meal_advisor/data/models/ingredient_photo_scan_input.dart';
import 'package:diabeatthis/features/meal_advisor/data/models/ingredient_scan_result.dart';
import 'package:diabeatthis/features/meal_advisor/data/parsers/ingredient_scan_result_parser.dart';
import 'package:diabeatthis/features/meal_advisor/domain/mappers/ingredient_scan_result_mapper.dart';
import 'package:diabeatthis/features/meal_advisor/domain/services/ingredient_scan_result_validator.dart';
import 'package:diabeatthis/features/meal_advisor/domain/use_cases/scan_ingredient_from_photos_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScanIngredientFromPhotosUseCase', () {
    setUp(() {
      Log.clearBuffer();
      LogRuntimeConfig.configure(enableBuffer: true, isUnitTest: true);
    });

    tearDown(() {
      Log.clearBuffer();
      LogRuntimeConfig.configure(enableBuffer: false, isUnitTest: false);
    });

    test(
      'parses debug scan response and maps it to ingredient draft',
      () async {
        const useCase = ScanIngredientFromPhotosUseCase(
          client: DebugIngredientPhotoScanClient(delay: Duration.zero),
          parser: IngredientScanResultParser(),
          validator: IngredientScanResultValidator(),
        );
        const input = IngredientPhotoScanInput(
          frontPhotoPath: 'front.jpg',
          nutritionLabelPhotoPath: 'nutrition.jpg',
        );

        final result = await useCase.call(input);
        final draft = result.toIngredientDraft();

        expect(result.status, IngredientScanStatus.recognized);
        expect(result.needsRetake, isFalse);
        expect(result.name, 'Testowy produkt');
        expect(result.brand, 'Przykładowy producent');
        expect(result.portions.single.name, '2 ciastka');
        expect(result.portions.single.grams, 25);
        expect(draft.name, 'Testowy produkt');
        expect(draft.brand, 'Przykładowy producent');
        expect(draft.carbsPer100g, 62.3);
        expect(draft.fatPer100g, 20.1);
        expect(draft.proteinPer100g, 6.4);
        expect(draft.fiberPer100g, 3.2);
        expect(draft.isReference, isFalse);
      },
    );

    test('logs raw scan response and recognized portions', () async {
      const useCase = ScanIngredientFromPhotosUseCase(
        client: DebugIngredientPhotoScanClient(delay: Duration.zero),
        parser: IngredientScanResultParser(),
        validator: IngredientScanResultValidator(),
      );
      const input = IngredientPhotoScanInput(
        frontPhotoPath: 'front.jpg',
        nutritionLabelPhotoPath: 'nutrition.jpg',
      );

      await useCase.call(input);

      final messages = Log.bufferedLogs
          .map((entry) => entry.message)
          .join('\n');
      expect(messages, contains('Raw ingredient scan response'));
      expect(messages, contains('Recognized ingredient portions'));
      expect(messages, contains('2 ciastka'));
      expect(messages, contains('grams=25.0'));
    });

    test('rejects scan without required photos', () async {
      const useCase = ScanIngredientFromPhotosUseCase(
        client: DebugIngredientPhotoScanClient(delay: Duration.zero),
        parser: IngredientScanResultParser(),
        validator: IngredientScanResultValidator(),
      );

      await expectLater(
        useCase.call(const IngredientPhotoScanInput(frontPhotoPath: 'x')),
        throwsStateError,
      );
    });
  });
}

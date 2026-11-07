import 'package:diabeatthis/features/ingredients/data/clients/ingredient_photo_scan_client.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/models/ingredient_photo_scan_input.dart';
import 'package:diabeatthis/features/ingredients/data/providers/ingredient_photo_scan_client_provider.dart';
import 'package:diabeatthis/features/ingredients/presentation/controllers/barcode_ingredient_review_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class BarcodeReviewPhotoClient implements IngredientPhotoScanClient {
  const BarcodeReviewPhotoClient(this.response);
  final String response;
  @override
  Future<String> scan(IngredientPhotoScanInput input) async => response;
}

void main() {
  const current = IngredientDraft.draft(
    name: 'Yogurt',
    barcode: '5901234123457',
    carbsPer100g: 5,
    fiberPer100g: 1,
    fatPer100g: 3,
    proteinPer100g: 8,
    nutritionConfidence: .5,
    isReference: false,
  );
  const input = IngredientPhotoScanInput(
    frontPhotoPath: 'front.jpg',
    nutritionLabelPhotoPath: 'label.jpg',
  );
  for (final response in [
    '{"status":"needsReview","name":"Yogurt","nutritionPer100g":{"carbs":12}}',
    '{"status":"recognized","barcode":"4006381333931"}',
    '{"status":"needsRetake"}',
  ]) {
    test(
      'label review preserves known facts and rejects identity/retake: $response',
      () async {
        final container = ProviderContainer(
          overrides: [
            ingredientPhotoScanClientProvider.overrideWithValue(
              BarcodeReviewPhotoClient(response),
            ),
          ],
        );
        addTearDown(container.dispose);
        final subscription = container.listen(
          barcodeIngredientReviewControllerProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);
        final result = await container
            .read(barcodeIngredientReviewControllerProvider.notifier)
            .readLabel(input, current);
        if (response.contains('needsReview')) {
          expect(result?.carbsPer100g, 12);
          expect(result?.proteinPer100g, 8);
          expect(result?.fiberPer100g, 1);
          expect(result?.barcode, current.barcode);
          expect(
            container.read(barcodeIngredientReviewControllerProvider).hasError,
            isFalse,
          );
        } else {
          expect(result, isNull);
          expect(
            container.read(barcodeIngredientReviewControllerProvider).hasError,
            isTrue,
          );
        }
      },
    );
  }
}

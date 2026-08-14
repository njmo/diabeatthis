import 'package:diabeatthis/features/ingredients/data/providers/ingredient_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

void main() {
  group('IngredientDraftNotifier', () {
    test('clears barcode when ingredient becomes reference', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(ingredientDraftProvider.notifier);

      notifier.setBarcode('8714800048378');
      notifier.setIsReference(true);

      final draft = container.read(ingredientDraftProvider);
      expect(draft.isReference, true);
      expect(draft.barcode, isNull);
    });
  });
}

import 'package:diabeatthis/core/domain/model/ingredient.dart';
import 'package:diabeatthis/core/domain/model/quick_low_treatment_item.dart';
import 'package:diabeatthis/features/low_treatment/presentation/formatters/quick_low_treatment_item_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formats reference quick item amount as reference portions', () {
    const item = QuickLowTreatmentItem(
      id: 1,
      name: 'Posiłek referencyjny',
      ingredient: Ingredient(
        id: 10,
        name: 'Posiłek referencyjny',
        carbsPer100g: 15,
        fatPer100g: 0,
        fiberPer100g: 0,
        proteinPer100g: 0,
        nutritionConfidence: 1,
        isReference: true,
      ),
      portion: null,
      amount: 1,
      sortOrder: 1,
      gramsPerPortion: null,
    );

    expect(
      formatQuickLowTreatmentItemDetails(item),
      '1 x porcja • 15 g węglowodanów',
    );
  });
}

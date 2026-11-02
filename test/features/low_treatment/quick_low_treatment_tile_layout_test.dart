import 'package:diabeatthis/core/domain/model/ingredient.dart';
import 'package:diabeatthis/core/domain/model/quick_low_treatment_item.dart';
import 'package:diabeatthis/features/low_treatment/data/providers/quick_low_treatment_item_provider.dart';
import 'package:diabeatthis/features/low_treatment/presentation/widgets/quick_low_treatment_selector.dart';
import 'package:diabeatthis/features/low_treatment/presentation/widgets/quick_low_treatment_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

const shortcutName = 'Komosa z ryżem i warzywami';
const shortcut = QuickLowTreatmentItem(
  id: 1,
  name: shortcutName,
  ingredient: Ingredient(
    id: 1,
    name: shortcutName,
    carbsPer100g: 20,
    fatPer100g: 0,
    fiberPer100g: 0,
    proteinPer100g: 0,
    nutritionConfidence: 1,
    isReference: false,
  ),
  portion: null,
  amount: 50,
  sortOrder: 1,
  gramsPerPortion: null,
);

void main() {
  for (final scale in [0.8, 1.0, 2.0]) {
    testWidgets('shortcut labels fit their tiles at text scale $scale', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            quickLowTreatmentItemsProvider.overrideWith(
              (_) => Stream.value([shortcut]),
            ),
          ],
          child: localizedMaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: QuickLowTreatmentSelector(onSelected: (_, _) {}),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final tile = find.byType(QuickLowTreatmentTile);
      final label = find.descendant(
        of: tile,
        matching: find.text(shortcutName),
      );
      final tileRect = tester.getRect(tile);
      final labelRect = tester.getRect(label);
      expect(labelRect.bottom, lessThanOrEqualTo(tileRect.bottom - 8));
      expect(labelRect.top, greaterThanOrEqualTo(tileRect.top + 8));
      expect(
        tester.renderObject<RenderParagraph>(label).didExceedMaxLines,
        isFalse,
      );

      final addButton = find.widgetWithText(OutlinedButton, 'Dodaj skrót');
      final addLabel = find.descendant(
        of: addButton,
        matching: find.text('Dodaj skrót'),
      );
      expect(
        tester.getRect(addLabel).bottom,
        lessThanOrEqualTo(tester.getRect(addButton).bottom - 8),
      );
    });
  }
}

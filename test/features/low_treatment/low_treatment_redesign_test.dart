import 'package:diabeatthis/common/models/timeline_relation.dart';
import 'package:diabeatthis/common/widgets/timeline_relation_picker.dart';
import 'package:diabeatthis/core/domain/model/ingredient.dart';
import 'package:diabeatthis/core/domain/model/quick_low_treatment_item.dart';
import 'package:diabeatthis/features/low_treatment/data/providers/quick_low_treatment_item_provider.dart';
import 'package:diabeatthis/features/low_treatment/presentation/widgets/quick_low_treatment_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  for (final value in [12, 120]) {
    testWidgets('quantity $value fits one line with large text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      double? changed;
      await tester.pumpWidget(
        localizedMaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 640),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: QuickLowTreatmentQuantityStepper(
                value: value.toDouble(),
                enabled: true,
                onChanged: (value) => changed = value,
              ),
            ),
          ),
        ),
      );
      final text = tester.widget<Text>(find.text('$value'));
      expect(text.maxLines, 1);
      expect(text.softWrap, isFalse);
      await tester.tap(find.byTooltip('Zwiększ ilość'));
      expect(changed, value + 0.5);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'quantity can be entered directly and must be at least half a serving',
    (tester) async {
      double? changed;
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: QuickLowTreatmentQuantityStepper(
              value: 12,
              enabled: true,
              onChanged: (value) => changed = value,
            ),
          ),
        ),
      );
      await tester.tap(find.text('12'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '0');
      await tester.tap(find.text('Zatwierdź'));
      await tester.pumpAndSettle();
      expect(find.text('Podaj wartość nie mniejszą niż 0,5.'), findsOneWidget);
      expect(changed, isNull);
      await tester.enterText(find.byType(TextFormField), '1,5');
      await tester.tap(find.text('Zatwierdź'));
      await tester.pumpAndSettle();
      expect(changed, 1.5);
    },
  );

  testWidgets(
    'half servings display with a comma and cannot decrease below half',
    (tester) async {
      double? changed;
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: QuickLowTreatmentQuantityStepper(
              value: 0.5,
              enabled: true,
              onChanged: (value) => changed = value,
            ),
          ),
        ),
      );
      expect(find.text('0,5'), findsOneWidget);
      await tester.tap(find.byTooltip('Zmniejsz ilość'));
      expect(changed, isNull);
      await tester.tap(find.byTooltip('Zwiększ ilość'));
      expect(changed, 1);
    },
  );

  testWidgets(
    'carousel selects the correct shortcut without changing its serving',
    (tester) async {
      final items = [
        for (var index = 1; index <= 3; index++)
          QuickLowTreatmentItem(
            id: index,
            name: 'Product $index',
            ingredient: Ingredient(
              id: index,
              name: 'Product $index',
              carbsPer100g: 100,
              fatPer100g: 0,
              fiberPer100g: 0,
              proteinPer100g: 0,
              nutritionConfidence: 1,
              isReference: false,
            ),
            portion: null,
            amount: index.toDouble(),
            sortOrder: index,
            gramsPerPortion: null,
          ),
      ];
      QuickLowTreatmentItem? chosen;
      double? quantity;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            quickLowTreatmentItemsProvider.overrideWith(
              (ref) => Stream.value(items),
            ),
          ],
          child: localizedMaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: QuickLowTreatmentSelector(
                  onSelected: (item, count) {
                    chosen = item;
                    quantity = count;
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(chosen?.id, 1);
      await tester.tap(find.text('Product 2'));
      await tester.pumpAndSettle();
      expect(chosen?.id, 2);
      expect(chosen?.amount, 2);
      expect(quantity, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('relation picker starts with requested category and can switch', (
    tester,
  ) async {
    final at = DateTime(2026, 10, 31, 12);
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: TimelineRelationPicker(
            occurredAt: at,
            initialKind: TimelineRelationKind.activity,
            load: (_) async => [
              TimelineRelation(
                id: 1,
                kind: TimelineRelationKind.activity,
                name: 'Walk',
                at: at,
              ),
              TimelineRelation(
                id: 2,
                kind: TimelineRelationKind.meal,
                name: 'Lunch',
                at: at,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Walk'), findsOneWidget);
    expect(find.text('Lunch'), findsNothing);
    await tester.tap(find.text('Posiłek'));
    await tester.pumpAndSettle();
    expect(find.text('Lunch'), findsOneWidget);
    expect(find.text('Walk'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

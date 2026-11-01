import 'package:diabeatthis/core/domain/model/ingredient.dart';
import 'package:diabeatthis/core/domain/model/low_treatment_context.dart';
import 'package:diabeatthis/core/domain/model/quick_low_treatment_item.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' show DatabaseImpl;
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/low_treatment/data/mappers/quick_low_treatment_item_mapper.dart';
import 'package:diabeatthis/features/low_treatment/presentation/controllers/low_treatment_context_controller.dart';
import 'package:diabeatthis/features/low_treatment/presentation/widgets/low_treatment_context_section.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  testWidgets(
    'context edits update the visible summary through the same provider scope',
    (tester) async {
      final db = DatabaseImpl(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          lowTreatmentContextControllerProvider.overrideWith(
            () => LowTreatmentContextController(
              historicalAt: DateTime(2026, 11, 1),
            ),
          ),
        ],
      );
      final subscription = container.listen(
        lowTreatmentContextControllerProvider,
        (_, _) {},
      );
      addTearDown(() async {
        subscription.close();
        container.dispose();
        await db.close();
      });
      await container.read(lowTreatmentContextControllerProvider.future);
      final ingredient = const QuickLowTreatmentItem(
        id: 1,
        name: 'TEST Juice',
        ingredient: Ingredient(
          id: 1,
          name: 'TEST Juice',
          carbsPer100g: 10,
          fatPer100g: 0,
          proteinPer100g: 0,
          fiberPer100g: 0,
          nutritionConfidence: 1,
          isReference: false,
        ),
        portion: null,
        amount: 100,
        sortOrder: 1,
        gramsPerPortion: null,
      ).toMealIngredientDraft();
      container
          .read(lowTreatmentContextControllerProvider.notifier)
          .addMealIngredient(ingredient);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedMaterialApp(
            home: const Scaffold(body: LowTreatmentContextSection()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Ręcznie'), findsOneWidget);
      expect(find.text('Bez powiązania'), findsOneWidget);
      await tester.tap(find.text('Edytuj'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byType(DropdownButtonFormField<LowTreatmentReason>),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Szybki spadek').last);
      await tester.pumpAndSettle();
      expect(
        container
            .read(lowTreatmentContextControllerProvider)
            .requireValue
            .reason,
        LowTreatmentReason.fallingTrend,
      );
      expect(
        container
            .read(lowTreatmentContextControllerProvider)
            .requireValue
            .reasonAutoSelected,
        isFalse,
      );
      await tester.tap(find.text('Gotowe'));
      await tester.pumpAndSettle();
      expect(find.text('Szybki spadek'), findsOneWidget);
      expect(
        container
            .read(lowTreatmentContextControllerProvider)
            .requireValue
            .mealIngredients
            .single,
        same(ingredient),
      );
      expect(tester.takeException(), isNull);
    },
  );
}

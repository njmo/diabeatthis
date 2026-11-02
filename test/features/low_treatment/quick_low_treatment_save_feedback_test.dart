import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/core/domain/model/quick_low_treatment_item.dart';
import 'package:diabeatthis/core/drift/database_impl.dart'
    show DatabaseImpl, IngredientCompanion;
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/low_treatment/data/models/quick_low_treatment_items_state.dart';
import 'package:diabeatthis/features/low_treatment/data/models/quick_low_treatment_slot.dart';
import 'package:diabeatthis/features/low_treatment/presentation/controllers/low_treatment_context_controller.dart';
import 'package:diabeatthis/features/low_treatment/presentation/controllers/quick_low_treatment_items_controller.dart';
import 'package:diabeatthis/features/low_treatment/presentation/widgets/low_treatment_sheet.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/add_meal_ingredient.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_ingredient_review.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  testWidgets(
    'shortcut save error is visible above the treatment sheet and can be closed',
    (tester) async {
      final db = DatabaseImpl(NativeDatabase.memory());
      await db
          .into(db.ingredient)
          .insert(
            IngredientCompanion.insert(
              name: 'TEST Juice',
              carbsPer100g: 10,
              fatPer100g: 0,
              fiberPer100g: 0,
              proteinPer100g: 0,
              nutritionConfidence: 1,
              iconAssetPath: const Value('assets/icons/food/prepared_meal.png'),
            ),
          );
      final failingController = FailingShortcutSaveController();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          lowTreatmentContextControllerProvider.overrideWith(
            () => LowTreatmentContextController(
              historicalAt: DateTime(2026, 10, 31),
            ),
          ),
          quickLowTreatmentItemsControllerProvider.overrideWith(
            () => failingController,
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: localizedMaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const LowTreatmentSheet(),
                  ),
                  child: const Text('Open treatment'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open treatment'));
      await tester.pumpAndSettle();
      expect(find.byType(LowTreatmentSheet), findsOneWidget);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Dodaj skrót'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('TEST Juice'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Wybierz TEST Juice'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Podsumowanie'));
      await tester.pumpAndSettle();
      expect(find.byType(MealIngredientReview), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Dodaj składnik'));
      await tester.pumpAndSettle();

      expect(failingController.submitted?.ingredient.name, 'TEST Juice');
      expect(find.byType(AddMealIngredient), findsNothing);
      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      expect(
        find
            .descendant(
              of: dialog,
              matching: find.text(lang.uiPortionWeightMustBeGreaterThan0G),
            )
            .hitTestable(),
        findsOneWidget,
      );
      final close = find.descendant(
        of: dialog,
        matching: find.widgetWithText(TextButton, 'Zamknij'),
      );
      expect(close.hitTestable(), findsOneWidget);
      await tester.tap(close);
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(LowTreatmentSheet), findsOneWidget);
      expect(
        find.widgetWithText(OutlinedButton, 'Dodaj skrót').hitTestable(),
        findsOneWidget,
      );
      expect(
        await db.quickLowTreatmentItemDao.getQuickLowTreatmentItems(),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

class FailingShortcutSaveController extends QuickLowTreatmentItemsController {
  MealIngredientsDraft? submitted;

  @override
  Future<QuickLowTreatmentItemsState> build() async =>
      QuickLowTreatmentItemsState(slots: buildQuickLowTreatmentSlots([]));

  @override
  Future<void> upsertSlot({
    required int slot,
    required MealIngredientsDraft mealIngredient,
    QuickLowTreatmentItem? existingItem,
  }) async {
    submitted = mealIngredient;
    throw ArgumentError(lang.uiPortionWeightMustBeGreaterThan0G);
  }
}

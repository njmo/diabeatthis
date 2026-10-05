import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_portion_draft.dart';
import 'package:diabeatthis/features/low_treatment/data/providers/low_treatment_handoff_provider.dart';
import 'package:diabeatthis/features/low_treatment/domain/use_cases/low_treatment_handoff_use_case.dart';
import 'package:diabeatthis/features/low_treatment/presentation/controllers/low_treatment_context_controller.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final fail in [false, true]) {
    test(
      'local meal and pending AAPS handoff are atomic (failure=$fail)',
      () async {
        final db = DatabaseImpl(NativeDatabase.memory());
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            if (fail)
              lowTreatmentHandoffUseCaseProvider.overrideWithValue(
                FailingHandoff(),
              ),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await db.close();
        });
        container.listen(lowTreatmentContextControllerProvider, (_, _) {});
        await container.read(lowTreatmentContextControllerProvider.future);
        final controller = container.read(
          lowTreatmentContextControllerProvider.notifier,
        );
        controller.addMealIngredient(
          MealIngredientsDraft(
            ingredient: IngredientDraft.draft(
              name: 'Glucose',
              carbsPer100g: 100,
              fatPer100g: 0,
              fiberPer100g: 0,
              proteinPer100g: 0,
              nutritionConfidence: 1,
              isReference: false,
            ),
            ingredientPortion: IngredientPortionDraft(
              portion: PortionSelection.empty(),
              amount: 1,
            ),
            amount: 10,
            quantityConfidence: 1,
            entryType: 'planned',
            consumedAmount: null,
            consumedConfidence: null,
          ),
        );
        if (fail) {
          await expectLater(controller.saveCurrentDraft(), throwsStateError);
          expect(await db.select(db.meal).get(), isEmpty);
          expect(await db.select(db.lowTreatmentContext).get(), isEmpty);
          expect(await db.select(db.lowTreatmentHandoff).get(), isEmpty);
        } else {
          final saved = await controller.saveCurrentDraft();
          final pending =
              (await db.select(db.lowTreatmentHandoff).get()).single;
          expect(pending.mealId, saved.mealId);
          expect(pending.expectedCarbs, 10);
          expect(pending.matchedTreatAt, isNull);
          expect(await db.select(db.lowTreatmentReview).get(), isEmpty);
        }
      },
    );
  }
}

class FailingHandoff extends Fake implements LowTreatmentHandoffUseCase {
  @override
  Future<void> registerPending({
    required int mealId,
    required DateTime savedAt,
    required DateTime? suggestionAt,
  }) async => throw StateError('Pending handoff unavailable');
}

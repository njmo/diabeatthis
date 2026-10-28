import 'package:diabeatthis/common/models/timeline_relation.dart';
import 'package:diabeatthis/core/domain/model/low_treatment_context.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_draft.dart';
import 'package:diabeatthis/features/ingredients/data/drafts/ingredient_portion_draft.dart';
import 'package:diabeatthis/features/low_treatment/presentation/controllers/low_treatment_context_controller.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:diabeatthis/features/portions/data/drafts/portion_draft.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'historical low treatment saves a manually selected future activity without live context',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      final time = DateTime(2026, 9, 10, 13, 5);
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          lowTreatmentContextControllerProvider.overrideWith(
            () => LowTreatmentContextController(historicalAt: time),
          ),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
      final subscription = container.listen(
        lowTreatmentContextControllerProvider,
        (_, _) {},
      );
      addTearDown(subscription.close);
      final initial = await container.read(
        lowTreatmentContextControllerProvider.future,
      );
      expect(initial.contextDraft.meal.plannedAt, time);
      expect(initial.contextDraft.suggestedCarbs, isNull);
      expect(initial.contextDraft.deviceStatusDate, isNull);
      expect(initial.contextDraft.relatedMealId, isNull);
      final controller = container.read(
        lowTreatmentContextControllerProvider.notifier,
      );
      final activity = await db
          .into(db.activity)
          .insert(
            ActivityCompanion.insert(
              name: 'PE',
              percentagePre: 0,
              percentagePost: 0,
            ),
          );
      final log = await db
          .into(db.activityLog)
          .insert(
            ActivityLogCompanion.insert(
              activityId: activity,
              startedAt: time
                  .add(const Duration(minutes: 10))
                  .millisecondsSinceEpoch,
            ),
          );
      controller.setRelatedRecord(
        TimelineRelation(
          id: log,
          kind: TimelineRelationKind.activity,
          name: 'PE',
          at: time.add(const Duration(minutes: 10)),
        ),
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
      final result = await controller.saveCurrentDraft();
      final meal = await db.mealDao.getMealById(result.mealId);
      expect(meal!.plannedAt, time.millisecondsSinceEpoch);
      expect(meal.purpose, 'lowTreatment');
      expect(result.relatedActivityLogId, log);
      expect(result.relatedMealId, isNull);
      expect(result.source, LowTreatmentContextSource.manual);
      expect(result.reason, LowTreatmentReason.manual);
      expect(result.suggestedCarbs, isNull);
    },
  );
}

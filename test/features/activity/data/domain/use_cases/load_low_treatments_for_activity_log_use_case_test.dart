import 'package:diabeatthis/core/domain/model/low_treatment_context.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/activity/data/domain/use_cases/load_low_treatments_for_activity_log_use_case.dart';
import 'package:diabeatthis/features/low_treatment/data/drafts/low_treatment_context_draft.dart';
import 'package:diabeatthis/features/low_treatment/data/mappers/low_treatment_context_draft_drift_mapper.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DatabaseImpl db;
  late ProviderContainer container;

  setUp(() {
    db = DatabaseImpl(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('loads low treatments related to activity log', () async {
    final activity = await db
        .into(db.activity)
        .insertReturning(
          ActivityCompanion.insert(
            name: 'Spacer',
            percentagePre: 20,
            percentagePost: 10,
          ),
        );
    final activityLog = await db
        .into(db.activityLog)
        .insertReturning(
          ActivityLogCompanion.insert(
            activityId: activity.id,
            startedAt: DateTime(2026, 5, 24, 12).millisecondsSinceEpoch,
            endedAt: Value(DateTime(2026, 5, 24, 13).millisecondsSinceEpoch),
          ),
        );
    final lowTreatmentAt = DateTime(2026, 5, 24, 12, 30);
    final lowTreatment = await db
        .into(db.meal)
        .insertReturning(
          MealCompanion.insert(
            name: 'Dosłodzenie',
            plannedAt: lowTreatmentAt.millisecondsSinceEpoch,
            summarizedAt: Value(lowTreatmentAt.millisecondsSinceEpoch),
            purpose: const Value('lowTreatment'),
            status: const Value('confirmed'),
          ),
        );
    final ingredient = await db
        .into(db.ingredient)
        .insertReturning(
          IngredientCompanion.insert(
            name: 'Glukoza',
            carbsPer100g: 100,
            fatPer100g: 0,
            fiberPer100g: 0,
            proteinPer100g: 0,
            nutritionConfidence: 1,
          ),
        );
    await db
        .into(db.mealIngredients)
        .insert(
          MealIngredientsCompanion.insert(
            mealId: lowTreatment.id,
            ingredientId: ingredient.id,
            amount: const Value(10),
            quantityConfidence: 1,
          ),
        );
    await db.lowTreatmentContextDao.upsertContextForMeal(
      LowTreatmentContextDraft(
        meal: MealDraft(
          name: 'Dosłodzenie',
          mealIngredients: const [],
          plannedAt: lowTreatmentAt,
          status: 'confirmed',
        ),
        relatedActivityLogId: activityLog.id,
        source: LowTreatmentContextSource.dashboardAction,
        reason: LowTreatmentReason.plannedActivity,
      ).copyWith(mealId: lowTreatment.id).toCompanion(),
    );

    final treatments = await container.read(
      activityLogLowTreatmentsUseCaseProvider(activityLog.id).future,
    );

    expect(treatments, hasLength(1));
    expect(treatments.single.meal.id, lowTreatment.id);
    expect(treatments.single.context.relatedActivityLogId, activityLog.id);
    expect(treatments.single.totalNetCarbsG, 10);
  });
}

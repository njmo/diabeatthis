import 'package:diabeatthis/core/domain/model/low_treatment_context.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/low_treatment/data/drafts/low_treatment_context_draft.dart';
import 'package:diabeatthis/features/low_treatment/data/mappers/low_treatment_context_draft_drift_mapper.dart';
import 'package:diabeatthis/features/meals/data/drafts/meal_draft.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DatabaseImpl db;

  setUp(() {
    db = DatabaseImpl(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'creates low treatment meal and stores AAPS suggestion context',
    () async {
      final relatedMeal = await db
          .into(db.meal)
          .insertReturning(
            MealCompanion.insert(name: 'Obiad', plannedAt: 1000),
          );
      final treatmentAt = DateTime.fromMillisecondsSinceEpoch(2000);
      final lowTreatment = await db.mealDao.createLowTreatmentEntry(
        name: 'Dosłodzenie',
        eatenAt: treatmentAt,
      );
      final suggestionAt = DateTime.fromMillisecondsSinceEpoch(1500);
      final deviceStatusDate = DateTime.fromMillisecondsSinceEpoch(1400);

      await db.lowTreatmentContextDao.upsertContextForMeal(
        LowTreatmentContextDraft.draft(
          meal: MealDraft(
            name: 'Dosłodzenie',
            mealIngredients: const [],
            plannedAt: treatmentAt,
            status: 'confirmed',
          ),
          relatedMealId: relatedMeal.id,
          source: LowTreatmentContextSource.aapsSuggestion,
          suggestedCarbs: 12,
          suggestedWithinMinutes: 10,
          suggestionAt: suggestionAt,
          deviceStatusDate: deviceStatusDate,
          reason: LowTreatmentReason.carbsReq,
        ).toCompanion(mealId: lowTreatment.id),
      );

      final storedTreatment = await db.mealDao.getMealById(lowTreatment.id);
      final context = await db.lowTreatmentContextDao.getContextForMeal(
        lowTreatment.id,
      );

      expect(storedTreatment?.purpose, 'lowTreatment');
      expect(storedTreatment?.status, 'confirmed');
      expect(storedTreatment?.plannedAt, treatmentAt.millisecondsSinceEpoch);
      expect(storedTreatment?.summarizedAt, treatmentAt.millisecondsSinceEpoch);
      expect(context?.mealId, lowTreatment.id);
      expect(context?.relatedMealId, relatedMeal.id);
      expect(context?.source, LowTreatmentContextSource.aapsSuggestion);
      expect(context?.suggestedCarbs, 12);
      expect(context?.suggestedWithinMinutes, 10);
      expect(context?.suggestionAt, suggestionAt);
      expect(context?.deviceStatusDate, deviceStatusDate);
      expect(context?.reason, LowTreatmentReason.carbsReq);
      expect(context?.isSynced, isFalse);

      final relatedContexts = await db.lowTreatmentContextDao
          .getContextsForRelatedMeal(relatedMeal.id);
      expect(relatedContexts.single.mealId, lowTreatment.id);
    },
  );

  test('excludes low treatments from nearest planned meal', () async {
    await db.mealDao.createLowTreatmentEntry(
      name: 'Dosłodzenie',
      eatenAt: DateTime.now().add(const Duration(minutes: 1)),
    );

    final meal = await db
        .into(db.meal)
        .insertReturning(
          MealCompanion.insert(
            name: 'Kolacja',
            plannedAt: DateTime.now()
                .add(const Duration(minutes: 10))
                .millisecondsSinceEpoch,
          ),
        );

    final nearest = await db.mealDao.getNearestMeal();

    expect(nearest?.id, meal.id);
  });
}

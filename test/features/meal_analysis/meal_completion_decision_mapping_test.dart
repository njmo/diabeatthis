import 'package:diabeatthis/common/meal/meal_completion_decision.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' show DatabaseImpl;
import 'package:diabeatthis/features/day_analysis/data/repositories/day_analysis_meal_repository.dart';
import 'package:diabeatthis/features/day_analysis/data/repositories/day_local_history_repository.dart';
import 'package:diabeatthis/features/meals/data/mappers/meal_ai_facts_mapper.dart';
import 'package:diabeatthis/features/meals/data/mappers/meal_details_data_mapper.dart';
import 'package:diabeatthis/features/meals/data/models/meal_details_data.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'saved choice reaches meal facts and day analysis without changing recorded nutrition',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final eatenAt = DateTime(2026, 11, 1, 12);
      final decision = MealCompletionDecision(
        choice: MealCarbsCorrectionChoice.withoutCorrection,
        recordedAt: eatenAt.add(const Duration(minutes: 12)),
        eatingEndedAt: eatenAt.add(const Duration(minutes: 10)),
        reportedCarbs: 40,
        consumedCarbs: 25,
        proposedCorrectionCarbs: -15,
      );
      await db.customStatement(
        "INSERT INTO meal(id,name,planned_at,status,completion_decision) VALUES(1,'Meal',?,'eaten',?)",
        [eatenAt.millisecondsSinceEpoch, decision.encode()],
      );
      final row = (await db.mealDao.getMealById(1))!;
      final meal = MealDetailsDataMapper(db: db).mapMeal(row);
      expect(meal.completionDecision!.encode(), decision.encode());
      final details = MealDetailsData(
        meal: meal,
        advisorDecision: null,
        ingredients: [],
        plannedSnapshot: null,
        consumedSnapshot: null,
        statusHistory: [],
      );
      const mapper = MealAiFactsMapper();
      expect(
        mapper.map(details).evidence.completionDecision!.encode(),
        decision.encode(),
      );
      expect(
        mapper
            .map(details, cutoff: decision.recordedAt)
            .evidence
            .completionDecision,
        isNotNull,
      );
      expect(
        mapper.map(details, cutoff: eatenAt).evidence.completionDecision,
        isNull,
      );
      final dayMeal = await DayAnalysisMealRepository(db).loadMeal(1);
      expect(dayMeal.evidence.completionDecision!.encode(), decision.encode());
      expect(dayMeal.macros, isNull);
      final review = await DayLocalHistoryRepository(db).loadRecordedMeals(
        eatenAt.subtract(const Duration(hours: 1)),
        eatenAt.add(const Duration(hours: 1)),
      );
      expect(review.single.completionDecision!.encode(), decision.encode());
    },
  );

  test('older meals with no completion choice keep unknown evidence', () async {
    final db = DatabaseImpl(NativeDatabase.memory());
    addTearDown(db.close);
    final eatenAt = DateTime(2026, 11, 1, 12);
    await db.customStatement(
      "INSERT INTO meal(id,name,planned_at,status) VALUES(1,'Older meal',?,'eaten')",
      [eatenAt.millisecondsSinceEpoch],
    );
    final row = (await db.mealDao.getMealById(1))!;
    expect(
      MealDetailsDataMapper(db: db).mapMeal(row).completionDecision,
      isNull,
    );
    expect(
      (await DayAnalysisMealRepository(
        db,
      ).loadMeal(1)).evidence.completionDecision,
      isNull,
    );
  });
}

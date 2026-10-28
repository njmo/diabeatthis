import 'package:diabeatthis/core/domain/model/bolus_wizard.dart';
import 'package:diabeatthis/core/domain/model/manual_bolus.dart';
import 'package:diabeatthis/core/domain/model/treatment_base.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' show DatabaseImpl;
import 'package:diabeatthis/features/day_analysis/data/repositories/day_analysis_meal_repository.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_linked_insulin_evidence.dart';
import 'package:diabeatthis/features/meal_analysis/domain/models/meal_record_evidence.dart';
import 'package:diabeatthis/features/meal_analysis/domain/serialization/meal_record_evidence_dml.dart';
import 'package:diabeatthis/features/meal_analysis/domain/use_cases/build_meal_insulin_evidence_use_case.dart';
import 'package:diabeatthis/features/meals/common/models/meal_wizard_assignment.dart';
import 'package:diabeatthis/features/meals/common/models/meal_wizard_relation_type.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../common/analysis/dml_aaps_context_test.dart'
    show calculatorRecords;
import 'meal_ai_test_fixtures.dart' show aiMealTime, aiObservation;

final time = aiMealTime.subtract(const Duration(minutes: 15));
BolusWizard wizard(String id, {String? remoteId, String? remoteSource}) {
  final original = calculatorRecords(time).whereType<BolusWizard>().single;
  return original.copyWith(
    localId: id,
    nightscoutObjectId: remoteId,
    remoteSource: remoteSource,
    calculatorResult: original.calculatorResult!.copyWith(totalInsulin: 1.5),
  );
}

MealWizardAssignment assignment({
  String? localId = 'wizard',
  String? remoteId,
  String? source,
  MealWizardRelationType type = MealWizardRelationType.initial,
  bool dismissed = false,
}) => MealWizardAssignment(
  id: 1,
  mealId: 1,
  localId: localId,
  remoteId: remoteId,
  remoteSource: source,
  type: type,
  dismissed: dismissed,
);

void main() {
  test(
    'unique same-submission bolus stays a candidate, not a confirmed delivery link',
    () {
      final bolus = ManualBolus(
        externalId: 'private',
        createdAt: time.add(const Duration(seconds: 2)),
        insulin: 1.5,
      );
      final rows = const BuildMealInsulinEvidenceUseCase()(
        mealId: 1,
        assignments: [assignment()],
        treatments: [wizard('wizard'), bolus],
        cutoff: aiMealTime,
      )!;
      expect(
        rows.single.association,
        MealBolusAssociation.temporalAmountCandidate,
      );
      expect(rows.single.bolusCandidate, same(bolus));
      expect(rows.single.role, MealWizardRelationType.initial);
    },
  );
  test(
    'missing, dismissed and source-mismatched relations are not inferred from timestamps',
    () {
      const build = BuildMealInsulinEvidenceUseCase();
      expect(
        build(mealId: 1, assignments: null, treatments: [], cutoff: aiMealTime),
        isNull,
      );
      expect(
        build(
          mealId: 1,
          assignments: [assignment(dismissed: true)],
          treatments: [wizard('wizard')],
          cutoff: aiMealTime,
        ),
        isEmpty,
      );
      final rows = build(
        mealId: 1,
        assignments: [
          assignment(localId: null, remoteId: 'same', source: 'source-a'),
        ],
        treatments: [wizard('x', remoteId: 'same', remoteSource: 'source-b')],
        cutoff: aiMealTime,
      )!;
      expect(rows.single.association, MealBolusAssociation.calculatorMissing);
    },
  );
  test(
    'multiple matching boluses or calculators cannot manufacture a precise waiting interval',
    () {
      const build = BuildMealInsulinEvidenceUseCase();
      final bolus = ManualBolus(
        externalId: 'b1',
        createdAt: time.add(const Duration(seconds: 1)),
        insulin: 1.5,
      );
      for (final history in <List<Treatment>>[
        [wizard('wizard'), bolus, bolus.copyWith(externalId: 'b2')],
        [wizard('wizard'), wizard('other'), bolus],
      ]) {
        final row = build(
          mealId: 1,
          assignments: [assignment()],
          treatments: history,
          cutoff: aiMealTime,
        )!.single;
        expect(row.association, MealBolusAssociation.bolusCandidateAmbiguous);
        expect(row.bolusCandidate, isNull);
      }
    },
  );
  test(
    'a later unrelated bolus and a calculator recommendation without delivery remain unresolved',
    () {
      final rows = const BuildMealInsulinEvidenceUseCase()(
        mealId: 1,
        assignments: [assignment(type: MealWizardRelationType.continuation)],
        treatments: [
          wizard('wizard'),
          ManualBolus(
            externalId: null,
            createdAt: time.add(const Duration(minutes: 5)),
            insulin: 1.5,
          ),
        ],
        cutoff: aiMealTime,
      )!;
      expect(rows.single.role, MealWizardRelationType.continuation);
      expect(
        rows.single.association,
        MealBolusAssociation.noRecordedBolusCandidate,
      );
    },
  );
  test(
    'DML distinguishes application wait, CGM timing and unknown saved confidence',
    () async {
      final observation = await aiObservation();
      final evidence = MealRecordEvidence(
        eatingTimeSource: MealEatingTimeSource.recordedStage,
        nutritionConfidence: const MealNutritionConfidence(
          carbsEffective: 0,
          fatProteinEffective: double.nan,
        ),
        wizardAssignments: [],
      );
      final dml = mealRecordEvidenceDml(
        mealId: 1,
        evidence: evidence,
        mealTime: aiMealTime,
        workflowWait: null,
        before: observation.before,
        outcome: observation.outcome,
      );
      expect(dml['workflow_wait_min'], isNull);
      expect((dml['nutrition_confidence'] as Map)['carbs_effective'], 0);
      expect(
        (dml['nutrition_confidence'] as Map)['fat_protein_effective'],
        isNull,
      );
      expect((dml['latest_cgm_before_meal'] as Map)['age_min'], 5);
      expect((dml['first_cgm_after_meal'] as Map)['delay_min'], 0);
    },
  );
  test(
    'day repository reads timing provenance, confidence and confirmed relation roles locally',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      await db.customStatement(
        "INSERT INTO meal(id,name,planned_at,status) VALUES(1,'Synthetic',?,'eaten')",
        [time.millisecondsSinceEpoch],
      );
      await db.customStatement(
        "INSERT INTO meal_status_history(meal_id,status,created_at) VALUES(1,'eating',?)",
        [aiMealTime.millisecondsSinceEpoch],
      );
      await db.customStatement(
        "INSERT INTO meal_snapshot(meal_id,snapshot_type,total_grams,total_carbs_g,total_fiber_g,total_net_carbs_g,total_fat_g,total_protein_g,total_calories_kcal,carb_weighted_effective_confidence) VALUES(1,'consumed',100,20,0,20,5,5,145,0.6)",
      );
      await db.customStatement(
        "INSERT INTO meal_wizard_link(meal_id,remote_wizard_id,remote_source,relation_type) VALUES(1,'remote','source','continuation')",
      );
      final loaded = await DayAnalysisMealRepository(db).loadMeal(1);
      expect(
        loaded.evidence.eatingTimeSource,
        MealEatingTimeSource.recordedStage,
      );
      expect(loaded.evidence.nutritionConfidence?.carbsEffective, 0.6);
      expect(
        loaded.evidence.wizardAssignments!.single.type,
        MealWizardRelationType.continuation,
      );
      expect(loaded.evidence.wizardAssignments!.single.recordedAt, isNotNull);
    },
  );
}

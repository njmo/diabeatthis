import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/model/low_treatment_context.dart';
import '../../../core/domain/model/meal.dart';
import '../../../core/drift/database_impl.dart'
    show LowTreatmentContextCompanion, MealSnapshotCompanion;
import '../../../core/drift/providers/database_provider.dart';
import '../../dashboard/data/providers/meal_snapshot_controller_provider.dart';
import '../../meals/data/domain/use_cases/add_meal_use_case.dart';
import '../data/drafts/low_treatment_context_draft.dart';
import '../data/providers/low_treatment_handoff_provider.dart';
import '../data/providers/low_treatment_upload_provider.dart';
import '../domain/use_cases/add_low_treatment_context_entry_use_case.dart';

final saveRecordedLowTreatmentUseCaseProvider =
    Provider<SaveRecordedLowTreatmentUseCase>((ref) {
      ref.watch(addMealUseCaseProvider);
      ref.watch(addLowTreatmentContextEntryUseCaseProvider);
      return SaveRecordedLowTreatmentUseCase(ref);
    });

/// One clinical transaction, shared by the editor and confirmed family requests.
class SaveRecordedLowTreatmentUseCase {
  const SaveRecordedLowTreatmentUseCase(this.ref);
  final Ref ref;

  Future<({LowTreatmentContext context, LowTreatmentContextDraft draft})> call(
    LowTreatmentContextDraft draft, {
    DateTime? historicalAt,
    DateTime? eatenAt,
    bool suggestMissingIcons = true,
    bool logContent = true,
    ({double nutrition, int delivery})? carbohydrateRecord,
  }) async {
    final addContext = ref.read(addLowTreatmentContextEntryUseCaseProvider);
    if (draft.mealId != null) {
      return (
        context: await addContext(draft, mealId: draft.mealId!),
        draft: draft,
      );
    }
    final db = ref.read(databaseProvider);
    return db.transaction(() async {
      if ((historicalAt ?? eatenAt)?.isAfter(clock.now()) ?? false) {
        throw ArgumentError('Historical low treatment cannot be in the future');
      }
      final mealDraft = draft.meal.copyWith(
        plannedAt: historicalAt ?? eatenAt ?? clock.now(),
        purpose: MealPurpose.lowTreatment,
      );
      final meal = await ref.read(addMealUseCaseProvider)(
        mealDraft,
        suggestMissingIcons: suggestMissingIcons,
        logContent: logContent,
      );
      final contextDraft = draft.copyWith(mealId: meal.id, meal: mealDraft);
      var context = await addContext(contextDraft, mealId: meal.id);
      if (carbohydrateRecord != null) {
        if (!carbohydrateRecord.nutrition.isFinite ||
            carbohydrateRecord.nutrition < .5 ||
            carbohydrateRecord.nutrition > 10000 ||
            carbohydrateRecord.delivery < 1 ||
            carbohydrateRecord.nutrition.round() !=
                carbohydrateRecord.delivery ||
            draft.meal.mealIngredients.any(
              (item) =>
                  item.ingredient.fiberPer100g != 0 ||
                  item.ingredient.fatPer100g != 0 ||
                  item.ingredient.proteinPer100g != 0,
            )) {
          throw ArgumentError('Invalid confirmed carbohydrate record');
        }
        await (db.update(
          db.lowTreatmentContext,
        )..where((row) => row.mealId.equals(meal.id))).write(
          LowTreatmentContextCompanion(
            recordedCarbs: Value(carbohydrateRecord.delivery),
          ),
        );
        context = context.copyWith(recordedCarbs: carbohydrateRecord.delivery);
        final snapshots = ref.read(mealSnapshotControllerProvider);
        await snapshots.createPlannedSnapshot(meal.id);
        await snapshots.saveConsumedSnapshot(meal.id);
        final frozen = await (db.select(
          db.mealSnapshot,
        )..where((row) => row.mealId.equals(meal.id))).get();
        if (!frozen.any((row) => row.snapshotType == 'planned') ||
            !frozen.any((row) => row.snapshotType == 'consumed')) {
          throw StateError('Confirmed nutrition snapshot was not saved');
        }
        await (db.update(
          db.mealSnapshot,
        )..where((row) => row.mealId.equals(meal.id))).write(
          MealSnapshotCompanion(
            totalCarbsG: Value(carbohydrateRecord.nutrition),
            totalNetCarbsG: Value(carbohydrateRecord.nutrition),
            totalCaloriesKcal: Value(carbohydrateRecord.nutrition * 4),
          ),
        );
      }
      if (historicalAt == null) {
        await ref
            .read(lowTreatmentHandoffUseCaseProvider)
            .registerPending(
              mealId: meal.id,
              savedAt: mealDraft.plannedAt,
              suggestionAt: context.deviceStatusDate == null
                  ? null
                  : context.suggestionAt,
            );
        await ref.read(registerLowTreatmentUploadUseCaseProvider)(meal.id);
      }
      return (context: context, draft: contextDraft);
    });
  }
}

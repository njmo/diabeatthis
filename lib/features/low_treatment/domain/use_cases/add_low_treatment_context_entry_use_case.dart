import 'package:drift/drift.dart' show Value;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/low_treatment_context.dart';
import '../../../../core/drift/database_impl.dart'
    show LowTreatmentContextCompanion;
import '../../../../core/drift/providers/database_provider.dart';
import '../../../../core/logger/logger.dart';
import '../../data/drafts/low_treatment_context_draft.dart';
import '../../data/mappers/low_treatment_context_draft_drift_mapper.dart';
import '../../data/repositories/recorded_low_treatment_repository.dart';

part 'add_low_treatment_context_entry_use_case.g.dart';

@riverpod
AddLowTreatmentContextEntryUseCase addLowTreatmentContextEntryUseCase(Ref ref) {
  return AddLowTreatmentContextEntryUseCase(ref: ref);
}

class AddLowTreatmentContextEntryUseCase with Logging {
  AddLowTreatmentContextEntryUseCase({required this.ref});

  final Ref ref;

  Future<LowTreatmentContext> call(
    LowTreatmentContextDraft draft, {
    required int mealId,
  }) async {
    final db = ref.read(databaseProvider);
    final contextDraft = draft.copyWith(mealId: mealId);

    final context = await db.lowTreatmentContextDao.upsertContextForMeal(
      contextDraft.toCompanion(),
    );

    if (context.recordedCarbs == null) {
      final recorded = await RecordedLowTreatmentRepository(
        db,
      ).fetchByMealId(mealId);
      final carbs = recorded?.netCarbsGrams;
      if (carbs != null && carbs.isFinite && carbs >= 0) {
        await (db.update(
          db.lowTreatmentContext,
        )..where((t) => t.mealId.equals(mealId))).write(
          LowTreatmentContextCompanion(recordedCarbs: Value(carbs.toInt())),
        );
        return (await db.lowTreatmentContextDao.getContextForMeal(mealId))!;
      }
    }
    logI('Saved low treatment context for meal $mealId');
    return context;
  }
}

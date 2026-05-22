import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/low_treatment_context.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../../../../core/logger/logger.dart';
import '../../data/drafts/low_treatment_context_draft.dart';
import '../../data/mappers/low_treatment_context_draft_drift_mapper.dart';

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

    logI('Saved low treatment context for meal $mealId');
    return context;
  }
}

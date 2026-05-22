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
    int? mealId,
  }) async {
    final db = ref.read(databaseProvider);
    final resolvedMealId = _resolveMealId(draft, mealId: mealId);

    await db.lowTreatmentContextDao.upsertContextForMeal(
      draft.toCompanion(mealId: resolvedMealId),
    );

    final context = await db.lowTreatmentContextDao.getContextForMeal(
      resolvedMealId,
    );
    if (context == null) {
      throw StateError('Could not load low treatment context $resolvedMealId.');
    }
    logI('Saved low treatment context for meal $resolvedMealId');
    return context;
  }

  int _resolveMealId(LowTreatmentContextDraft draft, {int? mealId}) {
    if (mealId != null) {
      return mealId;
    }

    return draft.map(
      draft: (_) {
        throw StateError(
          'Draft low treatment context requires persisted mealId.',
        );
      },
      existing: (existing) => existing.mealId,
    );
  }
}

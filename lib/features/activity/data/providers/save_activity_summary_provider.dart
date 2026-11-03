import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/drift/providers/database_provider.dart';
import '../domain/use_cases/save_activity_summary_use_case.dart';
import '../domain/use_cases/update_completed_activity_entry_use_case.dart';
import 'update_completed_activity_times_provider.dart';

final saveActivitySummaryUseCaseProvider = Provider(
  (ref) => SaveActivitySummaryUseCase(
    saveCompleted: ref
        .watch(databaseProvider)
        .activityDao
        .updateCompletedActivitySummary,
  ),
);

final updateCompletedActivityEntryUseCaseProvider = Provider((ref) {
  final db = ref.watch(databaseProvider);
  return UpdateCompletedActivityEntryUseCase(
    updateTimes: ref.watch(updateCompletedActivityTimesUseCaseProvider),
    saveSummary: ref.watch(saveActivitySummaryUseCaseProvider),
    transaction: (action) => db.transaction(action),
  );
});

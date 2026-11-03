import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/drift/database_impl.dart';
import '../../../../core/drift/providers/database_provider.dart';
import '../domain/use_cases/delete_activity_history_entry_use_case.dart';

final deleteActivityHistoryEntryProvider = FutureProvider.autoDispose
    .family<void, int>((ref, id) async {
      final db = ref.watch(databaseProvider);
      await DeleteActivityHistoryEntryUseCase(
        deleteById: (value) => db.activityDao.removeActivityLog(
          ActivityLogCompanion(id: Value(value)),
        ),
      )(id);
    });

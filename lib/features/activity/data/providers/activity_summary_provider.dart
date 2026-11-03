import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/drift/providers/database_provider.dart';
import '../mappers/activity_log_summary_data_mapper.dart';
import '../models/activity_log_summary_data.dart';

final completedActivitySummariesProvider =
    StreamProvider.autoDispose<List<ActivityLogSummaryData>>((ref) {
      return ref
          .watch(databaseProvider)
          .activityDao
          .watchCompletedActivitySummaries()
          .map(
            (rows) => rows
                .where((row) => row.log.summarizedAt == null)
                .map((row) => row.toSummaryData())
                .toList(),
          );
    });

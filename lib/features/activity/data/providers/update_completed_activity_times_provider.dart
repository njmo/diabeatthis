import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/drift/providers/database_provider.dart';
import '../domain/use_cases/update_completed_activity_times_use_case.dart';

final updateCompletedActivityTimesUseCaseProvider = Provider(
  (ref) => UpdateCompletedActivityTimesUseCase(
    now: clock.now,
    updateIfUnchanged: ref
        .watch(databaseProvider)
        .activityDao
        .updateCompletedActivityLogTimes,
  ),
);

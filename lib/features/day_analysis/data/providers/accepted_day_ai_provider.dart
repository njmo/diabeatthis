import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/drift/providers/database_provider.dart';
import '../../domain/models/accepted_day_analysis.dart';
import '../../domain/models/day_summary_snapshot.dart';
import '../../domain/use_cases/accept_day_analysis_use_case.dart';
import '../repositories/day_ai_repository.dart';

final dayAiRepositoryProvider = Provider(
  (ref) => DayAiRepository(ref.watch(databaseProvider)),
);

final acceptedDayAiProvider = FutureProvider.autoDispose
    .family<AcceptedDayAnalysis?, DateTime>(
      (ref, date) =>
          ref.watch(dayAiRepositoryProvider).get(daySummaryKey(date)),
    );

final acceptDayAnalysisUseCaseProvider = Provider(
  (ref) => AcceptDayAnalysisUseCase(
    save: ref.watch(dayAiRepositoryProvider).save,
    now: clock.now,
  ),
);

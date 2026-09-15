import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/day_analysis_history_provider.dart';
import '../../data/providers/day_summary_provider.dart';
import '../../domain/models/day_dml_document.dart';
import '../../domain/serialization/day_analysis_dml_serializer.dart';
import '../../domain/use_cases/build_day_analysis_context_use_case.dart';

final dayDmlProvider = AsyncNotifierProvider.autoDispose
    .family<DayAnalysisInputController, DayDmlDocument?, DateTime>(
      DayAnalysisInputController.new,
    );

/// Prepares one input for the panel. Model regeneration reuses this document.
class DayAnalysisInputController extends AsyncNotifier<DayDmlDocument?> {
  final DateTime date;
  DayAnalysisInputController(this.date);

  @override
  Future<DayDmlDocument?> build() async {
    final accepted = await ref.watch(acceptedDaySummaryProvider(date).future);
    if (accepted == null || !ref.mounted) return null;
    final history = await ref.read(loadDayAnalysisHistoryProvider)(accepted);
    if (!ref.mounted) return null;
    return serializeDayAnalysisContext(
      await const BuildDayAnalysisContextUseCase()(accepted, history),
    );
  }

  Future<void> retry() async {
    if (!state.hasError || state.isLoading) return;
    ref.invalidate(loadDayAnalysisHistoryProvider);
    ref.invalidateSelf();
  }
}

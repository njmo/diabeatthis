import '../models/accepted_day_analysis.dart';
import '../models/day_analysis_draft.dart';

class AcceptDayAnalysisUseCase {
  final Future<void> Function(String, AcceptedDayAnalysis) save;
  final DateTime Function() now;
  const AcceptDayAnalysisUseCase({required this.save, required this.now});

  Future<void> call(String dayKey, DayAnalysisDraft draft) =>
      save(dayKey, AcceptedDayAnalysis(analysis: draft, acceptedAt: now()));
}

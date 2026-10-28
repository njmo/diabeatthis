import 'activity_draft.dart';

class DashboardActivityAction {
  const DashboardActivityAction({
    required this.activity,
    required this.startedAt,
    required this.isScheduled,
    this.endedAt,
    this.durationMinutes,
  });
  final ActivityDraft activity;
  final DateTime startedAt;
  final bool isScheduled;
  final DateTime? endedAt;
  final int? durationMinutes;
}

import 'activity_draft.dart';
import 'activity_schedule_draft.dart';

class DashboardActivityAction {
  const DashboardActivityAction({
    required this.activity,
    required this.startedAt,
    required this.isScheduled,
    this.endedAt,
    this.durationMinutes,
    this.schedule,
  });
  final ActivityDraft activity;
  final ActivityScheduleDraft? schedule;
  final DateTime startedAt;
  final bool isScheduled;
  final DateTime? endedAt;
  final int? durationMinutes;
}

import '../../../../core/domain/model/temporary_target.dart';
import '../../../activity/data/models/activity_log_summary_data.dart';

class DashboardStatusViewModel {
  const DashboardStatusViewModel({
    required this.now,
    this.activity,
    this.linkedTarget,
    this.completedActivities = const [],
    this.linkedCompletedActivityId,
    this.standaloneTarget,
    this.canAttachActivity = false,
    this.loading = false,
  });
  final DateTime now;
  final ActivityLogSummaryData? activity;
  final TemporaryTarget? linkedTarget;
  final List<ActivityLogSummaryData> completedActivities;
  final int? linkedCompletedActivityId;
  final TemporaryTarget? standaloneTarget;
  final bool canAttachActivity;
  final bool loading;
}

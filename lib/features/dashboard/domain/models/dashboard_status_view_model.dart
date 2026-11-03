import '../../../../core/domain/model/temporary_target.dart';
import '../../../activity/data/models/activity_log_summary_data.dart';

class DashboardStatusViewModel {
  const DashboardStatusViewModel({
    required this.now,
    this.activity,
    this.linkedTarget,
    this.standaloneTarget,
    this.canAttachActivity = false,
    this.loading = false,
  });
  final DateTime now;
  final ActivityLogSummaryData? activity;
  final TemporaryTarget? linkedTarget;
  final TemporaryTarget? standaloneTarget;
  final bool canAttachActivity;
  final bool loading;
}

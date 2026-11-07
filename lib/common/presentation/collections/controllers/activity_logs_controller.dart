import '../../../../features/activity/data/models/activity_log_summary_data.dart';
import '../models/collection_state.dart';
import 'collection_controller.dart';

abstract interface class ActivityLogsController
    implements CollectionController<ActivityLogSummaryData> {
  void Function(ActivityLogSummaryData)? get open;
  Future<bool> Function(ActivityLogSummaryData)? get delete;
}

/// Adapts an already observed local snapshot without adding another subscription.
class PatientActivityLogsController implements ActivityLogsController {
  const PatientActivityLogsController({
    required this.state,
    required this.open,
    required this.onLoadMore,
    required this.onRetry,
    required this.delete,
  });
  @override
  final CollectionState<ActivityLogSummaryData> state;
  @override
  final void Function(ActivityLogSummaryData)? open;
  @override
  final Future<bool> Function(ActivityLogSummaryData)? delete;
  final void Function() onLoadMore;
  final void Function() onRetry;
  @override
  void loadMore() => onLoadMore();
  @override
  void retry() => onRetry();
}

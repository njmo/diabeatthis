import '../../../../core/domain/model/activity.dart';
import '../models/collection_state.dart';
import 'collection_controller.dart';

abstract interface class ActivitiesController
    implements CollectionController<Activity> {
  void Function(Activity)? get open;
}

/// Adapts an already observed local snapshot without adding another subscription.
class PatientActivitiesController implements ActivitiesController {
  const PatientActivitiesController({
    required this.state,
    required this.open,
    required this.onLoadMore,
    required this.onRetry,
  });
  @override
  final CollectionState<Activity> state;
  @override
  final void Function(Activity)? open;
  final void Function() onLoadMore;
  final void Function() onRetry;
  @override
  void loadMore() => onLoadMore();
  @override
  void retry() => onRetry();
}

import '../../../../core/domain/model/meal.dart';
import '../models/collection_state.dart';
import 'collection_controller.dart';

abstract interface class MealsController implements CollectionController<Meal> {
  void Function(Meal)? get open;
  Future<bool> Function(Meal)? get delete;
}

/// Adapts an already observed local snapshot without adding another subscription.
class PatientMealsController implements MealsController {
  const PatientMealsController({
    required this.state,
    required this.open,
    required this.onLoadMore,
    required this.onRetry,
    required this.delete,
  });
  @override
  final CollectionState<Meal> state;
  @override
  final void Function(Meal)? open;
  @override
  final Future<bool> Function(Meal)? delete;
  final void Function() onLoadMore;
  final void Function() onRetry;
  @override
  void loadMore() => onLoadMore();
  @override
  void retry() => onRetry();
}

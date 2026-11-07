import '../../../../core/domain/model/ingredient.dart';
import '../models/collection_state.dart';
import 'collection_controller.dart';

abstract interface class IngredientsController
    implements CollectionController<Ingredient> {
  void Function(Ingredient)? get open;
}

/// Adapts an already observed local snapshot without adding another subscription.
class PatientIngredientsController implements IngredientsController {
  const PatientIngredientsController({
    required this.state,
    required this.open,
    required this.onLoadMore,
    required this.onRetry,
  });
  @override
  final CollectionState<Ingredient> state;
  @override
  final void Function(Ingredient)? open;
  final void Function() onLoadMore;
  final void Function() onRetry;
  @override
  void loadMore() => onLoadMore();
  @override
  void retry() => onRetry();
}

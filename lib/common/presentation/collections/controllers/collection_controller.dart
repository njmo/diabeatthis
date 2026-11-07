import '../models/collection_state.dart';

/// Presentation actions are supplied by the owning source, never inferred in UI.
abstract interface class CollectionController<T> {
  CollectionState<T> get state;
  void loadMore();
  void retry();
}

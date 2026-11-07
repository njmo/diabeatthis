/// A source-independent snapshot. Controllers adapt local or family data into it.
class CollectionState<T> {
  const CollectionState({
    required this.items,
    this.loading = false,
    this.loadingMore = false,
    this.hasMore = false,
    this.failed = false,
  });
  final List<T> items;
  final bool loading;
  final bool loadingMore;
  final bool hasMore;
  final bool failed;
}

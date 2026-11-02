/// Groups loaded history entries by local calendar day, preserving their order.
class HistoryDayGroup<T> {
  const HistoryDayGroup({required this.date, required this.items});

  final DateTime? date;
  final List<T> items;
}

List<HistoryDayGroup<T>> groupHistoryByDay<T>(
  Iterable<T> items,
  DateTime? Function(T) dateOf,
) {
  final groups = <DateTime?, List<T>>{};
  for (final item in items) {
    final local = dateOf(item)?.toLocal();
    final day = local == null
        ? null
        : DateTime(local.year, local.month, local.day);
    groups.putIfAbsent(day, () => []).add(item);
  }
  return [
    for (final entry in groups.entries)
      HistoryDayGroup(date: entry.key, items: entry.value),
  ];
}

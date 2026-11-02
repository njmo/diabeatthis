import 'package:diabeatthis/common/history/history_day_group.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('groups by calendar day without losing order or undated entries', () {
    final items = [
      DateTime(2026, 11, 2, 20, 30),
      DateTime(2026, 11, 2, 19, 35),
      DateTime(2026, 9, 10, 20),
      null,
    ];
    final groups = groupHistoryByDay(items, (item) => item);
    expect(groups.map((group) => group.date), [
      DateTime(2026, 11, 2),
      DateTime(2026, 9, 10),
      null,
    ]);
    expect(groups.first.items, items.take(2));
    expect(groups.expand((group) => group.items), items);
  });

  test('uses local dates for UTC entries', () {
    final utc = DateTime.utc(2026, 11, 2, 23, 30);
    final local = utc.toLocal();
    final groups = groupHistoryByDay([utc], (item) => item);
    expect(groups.single.date, DateTime(local.year, local.month, local.day));
  });
}

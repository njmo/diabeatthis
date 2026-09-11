import 'package:diabeatthis/common/history/has_continuous_history.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 9, 9, 20);
  bool continuous(List<int> seconds) => hasContinuousHistory(
    timestamps: seconds.map((s) => start.add(Duration(seconds: s))),
    start: start,
    end: start.add(const Duration(minutes: 20)),
  );
  test(
    'regular samples tolerate timestamp jitter without changing measured coverage',
    () {
      expect(continuous([0, 301, 602, 903]), isTrue);
    },
  );
  test('sample count cannot hide internal or trailing gaps', () {
    expect(continuous([0, 60, 120, 180]), isFalse);
    expect(continuous([0, 60, 900, 1200]), isFalse);
    expect(continuous([0, 300, 600]), isFalse);
  });
  test('arbitrary phase, duplicates and ordering do not change continuity', () {
    expect(continuous([1199, 299, 899, 599, 599]), isTrue);
    expect(continuous([]), isFalse);
    expect(continuous([600, 900, 1200]), isFalse);
  });
}

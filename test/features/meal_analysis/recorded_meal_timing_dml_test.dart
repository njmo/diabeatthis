import 'package:diabeatthis/features/meal_analysis/domain/serialization/recorded_meal_timing_dml.dart';
import 'package:diabeatthis/features/meals/domain/models/recorded_meal_timing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime.utc(2026, 5, 7, 9);
  final eating = start.add(const Duration(minutes: 14));
  final end = eating.add(const Duration(minutes: 8));
  DateTime? parsed(Object? value) =>
      value == null ? null : DateTime.parse(value as String);

  test('waiting is distinct from eating and actual insulin delivery', () {
    final stages = [
      (status: 'eaten', at: end),
      (
        status: 'bolused-waiting',
        at: start.subtract(const Duration(minutes: 5)),
      ),
      (status: 'eating', at: eating),
      (status: 'bolused-waiting', at: start),
      (status: 'bolused-waiting', at: end.add(const Duration(minutes: 5))),
    ];
    final facts = recordedMealTimingDml(stages);
    expect(parsed(facts['waiting_started_at']), start);
    expect(parsed(facts['eating_started_at']), eating);
    expect(parsed(facts['eating_ended_at']), end);
    expect(
      RecordedMealTiming(stages).recordedWait,
      const Duration(minutes: 14),
    );
    expect(facts.keys, isNot(contains('bolus_delivered_at')));
  });

  test('missing stages never invent an eating or waiting time', () {
    final facts = recordedMealTimingDml([(status: 'summarized', at: end)]);
    expect(facts.values, everyElement(isNull));
  });

  test(
    'food-first ending uses waiting-for-bolus without inventing a wait before food',
    () {
      final facts = recordedMealTimingDml([
        (status: 'eating-then-bolus', at: eating),
        (status: 'waiting-for-bolus', at: end),
        (status: 'eaten-bolused', at: end.add(const Duration(minutes: 10))),
      ]);
      expect(facts['waiting_started_at'], isNull);
      expect(parsed(facts['eating_ended_at']), end);
    },
  );
}

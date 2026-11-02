import 'package:diabeatthis/common/meal/meal_completion_timing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 11, 1, 14, 52);
  test('duration follows actual eating start rather than plan or bolus', () {
    final timing = MealCompletionTiming.fromHistory([
      (status: 'planned', at: start.subtract(const Duration(hours: 1))),
      (
        status: 'bolused-waiting',
        at: start.subtract(const Duration(minutes: 15)),
      ),
      (status: 'waited-eating', at: start),
    ]);
    expect(timing.startedAt, start);
    expect(
      timing.needsTimeConfirmation(start.add(const Duration(minutes: 59))),
      isFalse,
    );
    expect(
      timing.needsTimeConfirmation(start.add(const Duration(minutes: 60))),
      isTrue,
    );
  });

  test(
    'late notification confirmation is still recognized after eaten status',
    () {
      final timing = MealCompletionTiming.fromHistory([
        (status: 'eating', at: start),
        (status: 'eaten', at: start.add(const Duration(hours: 5))),
      ]);
      expect(
        timing.needsTimeConfirmation(start.add(const Duration(hours: 6))),
        isTrue,
      );
      expect(timing.endStatus, 'eaten');
    },
  );

  test(
    'known timely completion does not become late merely by opening later',
    () {
      final timing = MealCompletionTiming.fromHistory([
        (status: 'eating', at: start),
        (status: 'eaten', at: start.add(const Duration(minutes: 15))),
      ]);
      expect(
        timing.needsTimeConfirmation(start.add(const Duration(hours: 5))),
        isFalse,
      );
    },
  );

  test('missing start requires explicit end time', () {
    final timing = MealCompletionTiming.fromHistory([]);
    expect(timing.needsTimeConfirmation(start), isTrue);
    expect(timing.isValidEnd(null, start), isFalse);
    expect(
      timing.isValidEnd(start.subtract(const Duration(hours: 1)), start),
      isTrue,
    );
    expect(
      timing.isValidEnd(start.add(const Duration(minutes: 1)), start),
      isFalse,
    );
  });

  test(
    'extra portion uses its own start while preserving initial meal timing',
    () {
      final extra = start.add(const Duration(hours: 2));
      final history = [
        (status: 'eating', at: start),
        (status: 'eaten', at: start.add(const Duration(minutes: 15))),
        (status: 'eating-extra', at: extra),
      ];
      final timing = MealCompletionTiming.fromHistory(
        history,
        currentStatus: 'eating-extra',
      );
      expect(timing.startedAt, extra);
      expect(timing.endedAt, isNull);
      expect(timing.isAddOn, isTrue);
      expect(
        timing.needsTimeConfirmation(extra.add(const Duration(minutes: 10))),
        isFalse,
      );
    },
  );

  test('missing extra start never reuses the original meal interval', () {
    final timing = MealCompletionTiming.fromHistory([
      (status: 'eating', at: start),
      (status: 'eaten', at: start.add(const Duration(minutes: 15))),
    ], currentStatus: 'eating-extra');
    expect(timing.startedAt, isNull);
    expect(timing.endedAt, isNull);
    expect(timing.isAddOn, isTrue);
    expect(
      timing.needsTimeConfirmation(start.add(const Duration(hours: 5))),
      isTrue,
    );
  });

  test('bolus timestamp never becomes the fallback eating end', () {
    final timing = MealCompletionTiming.fromHistory([
      (status: 'eaten-bolused', at: start.add(const Duration(hours: 5))),
    ], currentStatus: 'eaten-bolused');
    expect(timing.startedAt, isNull);
    expect(timing.endedAt, isNull);
    expect(timing.endStatus, 'eaten');
    expect(
      timing.needsTimeConfirmation(start.add(const Duration(hours: 5))),
      isTrue,
    );
  });
}

import 'package:diabeatthis/common/platform/aaps_suggestion_completion.dart';
import 'package:diabeatthis/core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final opened = DateTime(2026, 11, 3, 12);
  final submitted = opened
      .add(const Duration(minutes: 1))
      .millisecondsSinceEpoch;
  const suggestion = AapsBolusSuggestionNotificationEvent(
    carbs: 30,
    extendedCarbs: 15,
    extendedCarbsDelayMinutes: 45,
    extendedCarbsDurationMinutes: 120,
  );

  Map<String, dynamic> submission({
    bool complete = true,
    int? at,
    int carbs = 30,
  }) => {
    'at': at ?? submitted,
    'carbs': carbs,
    'valid': true,
    'complete': complete,
  };
  Map<String, dynamic> extended({
    bool valid = true,
    int grams = 15,
    int duration = 120,
  }) => {
    'id': 'extended-1',
    'at': submitted + const Duration(minutes: 45).inMilliseconds,
    'carbs': grams,
    'duration': Duration(minutes: duration).inMilliseconds,
    'valid': valid,
  };
  Map<String, dynamic> payload(
    List<Map<String, dynamic>> submissions, [
    Map<String, dynamic>? carb,
  ]) => {'submissions': submissions, if (carb != null) 'extendedCarb': carb};

  test(
    'waits for both confirmed delivery and the matching extended schedule',
    () {
      final tracker = AapsSuggestionCompletion(
        event: suggestion,
        openedAt: opened,
      );
      expect(tracker.update(payload([submission(complete: false)])), isFalse);
      expect(tracker.update(payload([submission()])), isFalse);
      expect(tracker.update(payload([submission()], extended())), isTrue);
    },
  );

  test(
    'extended carbs arriving first do not replace delivery confirmation',
    () {
      final tracker = AapsSuggestionCompletion(
        event: suggestion,
        openedAt: opened,
      );
      expect(
        tracker.update(payload([submission(complete: false)], extended())),
        isFalse,
      );
      expect(tracker.update(payload([submission()])), isTrue);
    },
  );

  test('wrong amounts, durations and invalidations keep the card open', () {
    final tracker = AapsSuggestionCompletion(
      event: suggestion,
      openedAt: opened,
    );
    expect(
      tracker.update(payload([submission()], extended(grams: 16))),
      isFalse,
    );
    expect(
      tracker.update(payload([submission()], extended(duration: 60))),
      isFalse,
    );
    expect(
      tracker.update(payload([submission()], extended(valid: false))),
      isFalse,
    );
  });

  test('old or ambiguous calculators cannot close a new card', () {
    final tracker = AapsSuggestionCompletion(
      event: suggestion,
      openedAt: opened,
    );
    expect(
      tracker.update(
        payload([
          submission(
            at: opened
                .subtract(const Duration(minutes: 1))
                .millisecondsSinceEpoch,
          ),
        ], extended()),
      ),
      isFalse,
    );
    expect(
      tracker.update(
        payload([submission(), submission(at: submitted + 1000)], extended()),
      ),
      isFalse,
    );
  });

  test(
    'ordinary carbs need a confirmed matching submission without e-carbs',
    () {
      final tracker = AapsSuggestionCompletion(
        event: const AapsBolusSuggestionNotificationEvent(carbs: 30),
        openedAt: opened,
      );
      expect(tracker.update(payload([submission(complete: false)])), isFalse);
      expect(tracker.update(payload([submission(carbs: 40)])), isFalse);
      expect(tracker.update(payload([submission()])), isTrue);
    },
  );

  test('e-carbs only can complete without requiring an unrelated bolus', () {
    final tracker = AapsSuggestionCompletion(
      event: const AapsBolusSuggestionNotificationEvent(
        carbs: 0,
        extendedCarbs: 15,
        extendedCarbsDelayMinutes: 45,
        extendedCarbsDurationMinutes: 120,
      ),
      openedAt: opened,
    );
    expect(tracker.update(payload([])), isFalse);
    expect(tracker.update(payload([], extended())), isTrue);
  });
}

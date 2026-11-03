import 'package:diabeatthis/common/platform/aaps_suggestion_completion.dart';
import 'package:diabeatthis/core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final opened = DateTime(2026, 11, 3, 12);
  const event = AapsBolusSuggestionNotificationEvent(
    carbs: 30,
    extendedCarbs: 15,
    extendedCarbsDelayMinutes: 45,
    extendedCarbsDurationMinutes: 120,
  );
  Map<String, dynamic> payload({
    String? id,
    bool complete = false,
    bool valid = true,
  }) => {
    'submissions': [
      {
        'at': opened.add(const Duration(seconds: 10)).millisecondsSinceEpoch,
        'carbs': 30,
        'valid': true,
        'complete': complete,
      },
    ],
    'extendedCarb': {
      'id': id,
      'at': opened
          .add(const Duration(minutes: 45, seconds: 10))
          .millisecondsSinceEpoch,
      'carbs': 15,
      'duration': const Duration(hours: 2).inMilliseconds,
      'valid': valid,
    },
  };

  test(
    'remote ID enrichment does not count the same extended record twice',
    () {
      final tracker = AapsSuggestionCompletion(event: event, openedAt: opened);
      expect(tracker.update(payload()), isFalse);
      expect(tracker.update(payload(id: 'remote-1')), isFalse);
      expect(tracker.update(payload(id: 'remote-1', complete: true)), isTrue);
    },
  );

  test('an ID-less invalidation updates the already identified record', () {
    final tracker = AapsSuggestionCompletion(event: event, openedAt: opened);
    expect(tracker.update(payload(id: 'remote-1')), isFalse);
    expect(tracker.update(payload(complete: true, valid: false)), isFalse);
  });

  test('two distinct remote records remain ambiguous', () {
    final tracker = AapsSuggestionCompletion(event: event, openedAt: opened);
    expect(tracker.update(payload(id: 'remote-1')), isFalse);
    expect(tracker.update(payload(id: 'remote-2', complete: true)), isFalse);
  });
}

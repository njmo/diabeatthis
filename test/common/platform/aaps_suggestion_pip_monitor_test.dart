import 'package:clock/clock.dart';
import 'package:diabeatthis/common/platform/aaps_suggestion_pip_monitor.dart';
import 'package:diabeatthis/core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 11, 3, 12);
  const event = AapsBolusSuggestionNotificationEvent(carbs: 30);
  final evidence = <String, dynamic>{
    'submissions': [
      {
        'at': now.add(const Duration(seconds: 10)).millisecondsSinceEpoch,
        'carbs': 30,
        'valid': true,
        'complete': true,
      },
    ],
  };

  test(
    'confirmation during PiP startup waits until the native window is ready',
    () {
      withClock(Clock.fixed(now), () {
        final dismissed = <String>[];
        final monitor = AapsSuggestionPipMonitor(
          dismiss: (id) async {
            dismissed.add(id);
          },
        );
        final id = monitor.begin(event);
        monitor.update(evidence);
        expect(dismissed, isEmpty);
        monitor.opened(id, true);
        expect(dismissed, [id]);
        monitor.update(evidence);
        expect(dismissed, [id]);
      });
    },
  );

  test('late startup completion cannot close a newer session', () {
    withClock(Clock.fixed(now), () {
      final dismissed = <String>[];
      final monitor = AapsSuggestionPipMonitor(
        dismiss: (id) async {
          dismissed.add(id);
        },
      );
      final oldId = monitor.begin(event);
      final currentId = monitor.begin(event);
      monitor.update(evidence);
      monitor.opened(oldId, true);
      expect(dismissed, isEmpty);
      monitor.opened(currentId, true);
      expect(dismissed, [currentId]);
    });
  });
}

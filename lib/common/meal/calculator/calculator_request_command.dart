import '../../../core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import '../../events/data/app_event_data.dart';

/// Registration goes to the owner in the foreground service, not to a UI waiter.
class CalculatorRequestCommand with AppEventData {
  const CalculatorRequestCommand({
    required this.event,
    required this.sessionId,
    required this.openedAt,
  });
  static const type = 'calculator_request';
  final AapsBolusSuggestionNotificationEvent event;
  final String sessionId;
  final DateTime openedAt;
  @override
  String get eventName => type;
  @override
  Map<String, dynamic> toJson() => {
    'event': event.toJson(),
    'sessionId': sessionId,
    'openedAt': openedAt.millisecondsSinceEpoch,
  };
}

import '../../../common/events/data/app_event_data.dart';
import '../model/foreground_event.dart';

/// The child muted or unmuted AAPS carbs request notifications. Wakes the
/// carbs request monitor so a shown notification is hidden right away.
class AapsCarbsRequestNotificationsChanged extends ForegroundEvent
    with AppEventData {
  const AapsCarbsRequestNotificationsChanged();

  static const command = 'aaps_carbs_request_notifications_changed';

  @override
  String get eventName => command;

  @override
  Map<String, dynamic> toJson() => const {};
}

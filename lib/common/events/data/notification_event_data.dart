mixin NotificationEventData {
  String get eventName;
  Map<String, dynamic> toJson();

  Map<String, dynamic> toExternalNotificationEventJson() => {
    'external_event': 'app_event',
    'data': {'app_event': eventName, 'data': toJson()},
  };
}

mixin TaskEventPayload {
  String get eventName;
  Map<String, dynamic> toJson();

  Map<String, dynamic> toTaskEventJson() => {
    'event': eventName,
    'data': toJson(),
  };
}
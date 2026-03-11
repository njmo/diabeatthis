mixin AppEventPayload {
  String get eventName;
  Map<String, dynamic> toJson();

  Map<String, dynamic> toEventJson() => {
    'event': eventName,
    'data': toJson(),
  };
}
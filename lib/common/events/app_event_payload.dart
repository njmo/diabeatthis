mixin AppEventPayload {
  String get eventName;
  Map<String, dynamic> toJson();

  Map<String, dynamic> toAppEventJson() => {
    'event': eventName,
    'data': toJson(),
  };
}
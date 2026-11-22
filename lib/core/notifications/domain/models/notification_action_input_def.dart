class NotificationActionInputDef {
  final String title;
  final String placeholderText;

  final int? minuteStep;

  const NotificationActionInputDef({
    required this.title,
    required this.placeholderText,
    this.minuteStep,
  });
}

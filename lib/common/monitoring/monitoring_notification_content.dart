class MonitoringNotificationContent {
  const MonitoringNotificationContent(this.title, this.text);
  final String title;
  final String text;

  @override
  bool operator ==(Object other) =>
      other is MonitoringNotificationContent &&
      other.title == title &&
      other.text == text;
  @override
  int get hashCode => Object.hash(title, text);
}

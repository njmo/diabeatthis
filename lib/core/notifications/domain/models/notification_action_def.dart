import 'notification_action_type.dart';

class NotificationActionDef {
  final NotificationActionType type;
  final String label;
  final bool openApp;

  const NotificationActionDef({
    required this.type,
    required this.label,
    this.openApp = true,
  });
}
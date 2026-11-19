import '../events/family_chat_notification.dart';
import 'notification_action_def.dart';
import 'notification_action_type.dart';
import 'notification_definition.dart';
import 'notification_event.dart';

/// The definition's actions that apply to this particular delivery, in the
/// order the system notification shows them. Shared by the Android mapper,
/// in-app banners and the inbox so every surface offers the same buttons.
List<NotificationActionDef> notificationActionsFor(
  NotificationEvent event,
  NotificationDefinition definition,
) => switch (event) {
  // Status updates (sent, pending, recorded) carry no message and no buttons.
  FamilyChatNotificationEvent(message: null) => const [],
  FamilyChatNotificationEvent(:final allowConsumption) => [
    for (final action in definition.actions)
      if (action.type != NotificationActionType.familyChatConsume ||
          allowConsumption)
        action,
  ],
  _ => definition.actions,
};

/// Suggested answers offered next to a text input.
List<String> notificationInputChoicesFor(NotificationEvent event) =>
    switch (event) {
      FamilyChatNotificationEvent(:final replyChoices) => replyChoices,
      _ => const [],
    };

import '../../../../common/l10n/language.dart';

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
  FamilyChatNotificationEvent(openRequest: true) => [
    NotificationActionDef.plain(
      type: NotificationActionType.familyChatOpenRequest,
      label: lang.familyChatOpenTreatmentRequest,
      openApp: true,
    ),
  ],
  // Status updates (sent, pending, recorded) carry no message and no buttons.
  FamilyChatNotificationEvent(message: null) => const [],
  FamilyChatNotificationEvent(allowConsumption: true) => [
    NotificationActionDef.plain(
      type: NotificationActionType.familyChatConsume,
      label: lang.familyChatTreatmentAnswerAte,
      openApp: true,
    ),
    NotificationActionDef.plain(
      type: NotificationActionType.familyChatTreatmentUnavailable,
      label: lang.familyChatTreatmentAnswerNone,
      openApp: false,
    ),
    NotificationActionDef.plain(
      type: NotificationActionType.familyChatTreatmentFeelsWell,
      label: lang.familyChatTreatmentAnswerFeelsWell,
      openApp: false,
    ),
  ],
  FamilyChatNotificationEvent(lowTreatment: true) => const [],
  FamilyChatNotificationEvent() => [
    for (final action in definition.actions)
      if (action.type == NotificationActionType.familyChatReply) action,
  ],
  _ => definition.actions,
};

/// Suggested answers offered next to a text input.
List<String> notificationInputChoicesFor(NotificationEvent event) =>
    switch (event) {
      FamilyChatNotificationEvent(:final replyChoices) => replyChoices,
      _ => const [],
    };

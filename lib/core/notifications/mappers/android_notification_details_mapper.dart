import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../base/notification_channel_definition_catalog.dart';
import '../base/notification_definition_catalog.dart';
import '../definitions/notification_channel_catalog_impl.dart';
import '../definitions/notification_definition_catalog_impl.dart';
import '../domain/events/family_chat_notification.dart';
import '../domain/models/notification_action_def.dart';
import '../domain/models/notification_action_type.dart';
import '../domain/models/notification_event.dart';
import '../domain/models/notification_event_actions.dart';
import '../domain/models/notification_event_type.dart';
import 'android_notification_action_mapper.dart';

class AndroidNotificationDetailsMapper {
  final NotificationDefinitionCatalog _catalog =
      NotificationDefinitionCatalogImpl();
  final NotificationChannelDefinitionCatalog _channelCatalog =
      NotificationChannelDefinitionCatalogImpl();
  final AndroidNotificationActionMapper _actionMapper =
      AndroidNotificationActionMapper();

  AndroidNotificationDetails map(NotificationEvent event) {
    final eventDefinition = _catalog.byType(event.type);
    final channelDefinition = _channelCatalog.byType(
      eventDefinition.channelType,
    );

    if (event is FamilyChatNotificationEvent) {
      final message = event.message;
      if (message == null) {
        return AndroidNotificationDetails(
          channelDefinition.id,
          channelDefinition.name,
          tag: event.tag,
          visibility: NotificationVisibility.private,
          onlyAlertOnce: true,
          timeoutAfter: event.timeoutAfter,
          silent: event.silent,
          actions: event.silent ? const [] : null,
        );
      }
      return AndroidNotificationDetails(
        channelDefinition.id,
        channelDefinition.name,
        tag: event.tag,
        importance: channelDefinition.importance,
        priority: Priority.high,
        visibility: NotificationVisibility.private,
        category: AndroidNotificationCategory.message,
        onlyAlertOnce: true,
        timeoutAfter: event.timeoutAfter,
        silent: event.silent,
        styleInformation: MessagingStyleInformation(
          Person(name: message.recipientName, key: message.recipientId),
          conversationTitle: message.conversationTitle,
          groupConversation: message.groupConversation,
          messages: [
            Message(
              event.body,
              message.sentAt,
              Person(name: message.senderName, key: message.senderId),
            ),
          ],
        ),
        actions: [
          for (final action in notificationActionsFor(event, eventDefinition))
            _familyChatAction(action, notificationInputChoicesFor(event)),
        ],
      );
    }

    return AndroidNotificationDetails(
      channelDefinition.id,
      channelDefinition.name,
      channelDescription: channelDefinition.description,
      importance: channelDefinition.importance,
      priority: Priority.high,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.reminder,
      groupKey: eventDefinition.categoryId,
      styleInformation: BigTextStyleInformation(event.body),
      actions: eventDefinition.actions
          .map(
            (action) => _actionMapper.map(
              action,
              showUserInterface:
                  event.type == NotificationEventType.finishedEating &&
                  action.type == NotificationActionType.agree,
            ),
          )
          .toList(),
    );
  }

  AndroidNotificationAction _familyChatAction(
    NotificationActionDef action,
    List<String> choices,
  ) => AndroidNotificationAction(
    action.type.toDarwinString(),
    action.label,
    cancelNotification: false,
    semanticAction: action is TextNotificationActionDef
        ? SemanticAction.reply
        : SemanticAction.none,
    inputs: [
      if (action case TextNotificationActionDef(:final inputActionDef))
        AndroidNotificationActionInput(
          label: inputActionDef.title,
          choices: choices,
        ),
    ],
  );
}

extension NotificationEventExtensions on NotificationEvent {
  AndroidNotificationDetails toAndroidNotificationDetails() =>
      AndroidNotificationDetailsMapper().map(this);
}

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../../common/l10n/language.dart';
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
  static const _familyChatIcon = 'ic_diabeatthis_notification';
  final NotificationDefinitionCatalog _catalog =
      NotificationDefinitionCatalogImpl();
  final NotificationChannelDefinitionCatalog _channelCatalog =
      NotificationChannelDefinitionCatalogImpl();
  final AndroidNotificationActionMapper _actionMapper =
      AndroidNotificationActionMapper();

  AndroidNotificationDetails map(
    NotificationEvent event, {
    bool retry = false,
  }) {
    final eventDefinition = _catalog.byType(event.type);
    final channelDefinition = _channelCatalog.byType(
      eventDefinition.channelType,
    );

    if (event is FamilyChatNotificationEvent) {
      final message = event.message;
      if (message == null || event.openRequest) {
        return AndroidNotificationDetails(
          channelDefinition.id,
          channelDefinition.name,
          icon: _familyChatIcon,
          tag: event.tag,
          visibility: NotificationVisibility.private,
          onlyAlertOnce: true,
          timeoutAfter: event.timeoutAfter,
          silent: event.silent,
          styleInformation: event.openRequest
              ? BigTextStyleInformation(event.body)
              : null,
          actions: event.openRequest
              ? [
                  for (final action in notificationActionsFor(
                    event,
                    eventDefinition,
                  ))
                    _familyChatAction(action, const []),
                ]
              : event.silent
              ? const []
              : null,
        );
      }
      final choices = event.allowConsumption || event.lowTreatment
          ? const <String>[]
          : notificationInputChoicesFor(event);
      return AndroidNotificationDetails(
        channelDefinition.id,
        channelDefinition.name,
        icon: _familyChatIcon,
        tag: event.tag,
        importance: channelDefinition.importance,
        priority: Priority.high,
        visibility: NotificationVisibility.private,
        category: AndroidNotificationCategory.message,
        onlyAlertOnce: !retry,
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
            _familyChatAction(action, choices),
          for (final (index, choice) in choices.take(3).indexed)
            AndroidNotificationAction(
              '${FamilyChatNotificationEvent.answerActionPrefix}$index',
              choice,
              cancelNotification: false,
            ),
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
    action is TextNotificationActionDef ? lang.familyChatReply : action.label,
    showsUserInterface: action.openApp,
    cancelNotification: action.type == NotificationActionType.familyChatConsume,
    semanticAction: action is TextNotificationActionDef
        ? SemanticAction.reply
        : SemanticAction.none,
    inputs: [
      if (action is TextNotificationActionDef)
        AndroidNotificationActionInput(
          label: lang.familyChatReply,
          choices: choices,
        ),
    ],
  );
}

extension NotificationEventExtensions on NotificationEvent {
  AndroidNotificationDetails toAndroidNotificationDetails({
    bool retry = false,
  }) => AndroidNotificationDetailsMapper().map(this, retry: retry);
}

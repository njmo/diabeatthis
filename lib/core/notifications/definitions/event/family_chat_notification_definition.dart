import '../../domain/models/notification_action_def.dart';
import '../../domain/models/notification_action_input_def.dart';
import '../../domain/models/notification_action_type.dart';
import '../../domain/models/notification_channel_type.dart';
import '../../domain/models/notification_definition.dart';
import '../../domain/models/notification_event_type.dart';

const familyChatNotificationDefinition = NotificationDefinition(
  type: NotificationEventType.familyChat,
  categoryId: 'family_chat',
  channelType: NotificationChannelType.familyChat,
  actions: [
    NotificationActionDef.plain(
      type: NotificationActionType.familyChatConsume,
      label: 'Zjadłem',
      openApp: true,
    ),
    NotificationActionDef.plain(
      type: NotificationActionType.familyChatTreatmentUnavailable,
      label: 'Nie mam',
      openApp: false,
    ),
    NotificationActionDef.text(
      type: NotificationActionType.familyChatReply,
      label: 'Odpowiedz',
      openApp: false,
      inputActionDef: NotificationActionInputDef(
        title: 'Odpowiedź',
        placeholderText: '',
      ),
    ),
  ],
);

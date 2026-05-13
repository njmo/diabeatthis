import '../../domain/models/notification_action_def.dart';
import '../../domain/models/notification_channel_type.dart';
import '../../domain/models/notification_definition.dart';
import '../../domain/models/notification_event_type.dart';

const aapsBolusSuggestionNotificationDefinition = NotificationDefinition(
  type: NotificationEventType.aapsBolusSuggestion,
  categoryId: 'aaps_bolus_suggestion',
  actions: <NotificationActionDef>[],
  channelType: NotificationChannelType.aapsSuggestion,
);

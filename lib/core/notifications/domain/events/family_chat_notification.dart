import '../models/notification_event.dart';
import '../models/notification_event_type.dart';
import '../models/notification_key.dart';

typedef FamilyChatNotificationMessage = ({
  String recipientId,
  String recipientName,
  String senderId,
  String senderName,
  String conversationTitle,
  bool groupConversation,
  DateTime sentAt,
});

/// An authenticated chat notification, already assigned an Android identity
/// by the durable family chat journal.
class FamilyChatNotificationEvent implements NotificationEvent {
  const FamilyChatNotificationEvent({
    required this.id,
    required this.tag,
    required this.title,
    required this.body,
    required this.payload,
    this.message,
    this.replyChoices = const [],
    this.allowConsumption = false,
    this.timeoutAfter,
    this.silent = false,
  });

  final int id;
  final String tag;
  @override
  final String title;
  @override
  final String body;
  final Map<String, Object?> payload;
  final FamilyChatNotificationMessage? message;
  final List<String> replyChoices;
  final bool allowConsumption;
  final int? timeoutAfter;
  final bool silent;

  @override
  NotificationEventType get type => NotificationEventType.familyChat;

  @override
  NotificationKey get key => NotificationKey(type: type, entityId: id);

  @override
  String get notificationResponseEvent => 'familyChat';

  @override
  Map<String, Object?> toPayload() => payload;

  @override
  Map<String, Object?> toJson() => payload;
}

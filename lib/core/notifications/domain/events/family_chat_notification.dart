import 'package:clock/clock.dart';

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
  static const answerActionPrefix = 'family_chat_answer_';

  const FamilyChatNotificationEvent({
    required this.id,
    required this.tag,
    required this.title,
    required this.body,
    required this.payload,
    this.message,
    this.replyChoices = const [],
    this.allowConsumption = false,
    this.lowTreatment = false,
    this.openRequest = false,
    this.timeoutAfter,
    this.silent = false,
    this.transient = false,
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
  final bool lowTreatment;
  final bool openRequest;
  final int? timeoutAfter;
  final bool silent;
  final bool transient;

  @override
  NotificationEventType get type => NotificationEventType.familyChat;

  @override
  NotificationKey get key => NotificationKey(type: type, entityId: id);

  @override
  String get notificationResponseEvent => 'familyChat';

  @override
  Map<String, Object?> toPayload() => payload;

  /// The full delivery, so the inbox can restore the banner with its id, tag
  /// and buttons. The Android payload itself stays [toPayload].
  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'tag': tag,
    'title': title,
    'body': body,
    'payload': payload,
    'replyChoices': replyChoices,
    'allowConsumption': allowConsumption,
    if (lowTreatment) 'lowTreatment': true,
    if (openRequest) 'openRequest': true,
    'silent': silent,
    if (transient) 'transient': true,
    if (timeoutAfter != null)
      'expiresAt': clock
          .now()
          .add(Duration(milliseconds: timeoutAfter!))
          .millisecondsSinceEpoch,
    if (message case final message?)
      'message': {
        'recipientId': message.recipientId,
        'recipientName': message.recipientName,
        'senderId': message.senderId,
        'senderName': message.senderName,
        'conversationTitle': message.conversationTitle,
        'groupConversation': message.groupConversation,
        'sentAt': message.sentAt.millisecondsSinceEpoch,
      },
  };

  /// Restores a delivery recorded by [toJson]. Once its Android lifetime has
  /// passed it can no longer be answered, so it comes back without buttons.
  factory FamilyChatNotificationEvent.fromJson(Map<String, dynamic> json) {
    final expiresAt = json['expiresAt'] as int?;
    final remaining = expiresAt == null
        ? null
        : expiresAt - clock.now().millisecondsSinceEpoch;
    final expired = remaining != null && remaining <= 0;
    final raw = json['message'] as Map?;
    return FamilyChatNotificationEvent(
      id: json['id'] as int,
      tag: json['tag'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      payload: Map<String, Object?>.from(json['payload'] as Map),
      message: raw == null || expired
          ? null
          : (
              recipientId: raw['recipientId'] as String,
              recipientName: raw['recipientName'] as String,
              senderId: raw['senderId'] as String,
              senderName: raw['senderName'] as String,
              conversationTitle: raw['conversationTitle'] as String,
              groupConversation: raw['groupConversation'] as bool,
              sentAt: DateTime.fromMillisecondsSinceEpoch(raw['sentAt'] as int),
            ),
      replyChoices: expired
          ? const []
          : List<String>.from(json['replyChoices'] as List? ?? const []),
      allowConsumption:
          !expired && (json['allowConsumption'] as bool? ?? false),
      lowTreatment:
          json['lowTreatment'] == true || json['allowConsumption'] == true,
      openRequest: !expired && json['openRequest'] == true,
      timeoutAfter: expired ? null : remaining,
      silent: json['silent'] as bool? ?? false,
      transient: json['transient'] as bool? ?? false,
    );
  }
}

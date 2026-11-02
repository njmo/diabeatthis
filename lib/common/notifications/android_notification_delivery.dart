import 'package:flutter_local_notifications/flutter_local_notifications.dart';

enum AndroidNotificationDeliveryBlock { applicationDisabled, channelDisabled }

class AndroidNotificationDeliveryException implements Exception {
  const AndroidNotificationDeliveryException({
    required this.reason,
    required this.channelId,
  });

  final AndroidNotificationDeliveryBlock reason;
  final String channelId;

  @override
  String toString() => switch (reason) {
    AndroidNotificationDeliveryBlock.applicationDisabled =>
      'Android notifications are disabled for this application.',
    AndroidNotificationDeliveryBlock.channelDisabled =>
      'Android notification channel "$channelId" is disabled.',
  };
}

/// Detects settings that would make Android silently discard a notification.
/// A missing channel is allowed because posting the notification creates it.
Future<void> ensureAndroidNotificationDeliveryEnabled(
  FlutterLocalNotificationsPlugin plugin, {
  required String channelId,
}) async {
  final android = plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();
  if (android == null) return;

  if (await android.areNotificationsEnabled() == false) {
    throw AndroidNotificationDeliveryException(
      reason: AndroidNotificationDeliveryBlock.applicationDisabled,
      channelId: channelId,
    );
  }

  final channels = await android.getNotificationChannels();
  if (channels == null) return;
  for (final channel in channels) {
    if (channel.id == channelId && channel.importance == Importance.none) {
      throw AndroidNotificationDeliveryException(
        reason: AndroidNotificationDeliveryBlock.channelDisabled,
        channelId: channelId,
      );
    }
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/controllers/local_notifications_controller.dart';
import '../../../core/notifications/providers/local_notifications_controller_provider.dart';

import 'family_chat_database.dart';

class FamilyChatNotificationPlatform {
  static Future<void> cancel(
    FamilyChatDatabase db,
    Iterable<FamilyChatNotice> notices, {
    bool Function()? keepTrying,
    Future<void> Function(FamilyChatNotice)? operation,
    LocalNotificationsController? controller,
  }) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    ProviderContainer? container;
    try {
      for (final notice in notices) {
        if (!await db.hasCancellationIntent(notice)) continue;
        while (true) {
          try {
            if (operation != null) {
              await operation(notice);
            } else {
              final delivery =
                  controller ??
                  (container ??= ProviderContainer())
                      .read<LocalNotificationsController>(
                        localNotificationsControllerProvider,
                      );
              await delivery.cancel(
                notice.id,
                tag: notice.tag.isEmpty ? null : notice.tag,
              );
            }
            await db.confirmCancelled(notice);
            break;
          } catch (_) {
            if (keepTrying?.call() == false) return;
            // Keep the durable cancellation intent and the guard closed.
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
        }
      }
    } finally {
      container?.dispose();
    }
  }
}

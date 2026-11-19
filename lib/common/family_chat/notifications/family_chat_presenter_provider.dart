import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/inbox/notification_inbox_entry.dart';
import '../../../core/notifications/providers/local_notifications_controller_provider.dart';
import '../../../core/notifications/providers/notifications_controller_provider.dart';
import '../data/family_chat_database_provider.dart';
import '../data/family_chat_guard_fence.dart';
import 'family_chat_presenter.dart';

/// Presenter for headless work (push handlers, notification responses):
/// system notifications mirrored into the inbox.
final familyChatPresenterProvider = Provider<AndroidFamilyChatPresenter>(
  (ref) => AndroidFamilyChatPresenter(
    controller: ref.watch(notificationsControllerHeadlessProvider),
    prepare: ref.watch(localNotificationsControllerProvider).initializeDelivery,
  ),
);

/// Presenter owned by the app UI: shows chat notifications as in-app banners
/// while the app is on screen, so one message never also reaches the tray.
final familyChatUiPresenterProvider = Provider<AndroidFamilyChatPresenter>(
  (ref) => AndroidFamilyChatPresenter(
    controller: ref.watch(notificationsControllerUiProvider),
    prepare: ref.watch(localNotificationsControllerProvider).initializeDelivery,
  ),
);

final familyChatInboxAccountProvider = StreamProvider<String?>(
  (ref) => Firebase.apps.isEmpty
      ? const Stream.empty()
      : FirebaseAuth.instance.authStateChanges().map((user) => user?.uid),
);

/// Checks the SQLite cleanup barriers before any saved chat body is shown.
final familyChatInboxVisibilityProvider =
    Provider<
      Future<List<NotificationInboxEntry>> Function(
        List<NotificationInboxEntry>,
      )
    >(
      (ref) => (entries) async {
        if (Firebase.apps.isEmpty) return const [];
        final auth = FirebaseAuth.instance;
        final uid = auth.currentUser?.uid;
        if (uid == null) return const [];
        final db = ref.read(familyChatDatabaseProvider);
        if (await db.fence.blocked()) return const [];
        final allowed = await db.authorizedInbox(uid, entries);
        return !await db.fence.blocked() && auth.currentUser?.uid == uid
            ? allowed
            : const [];
      },
    );

/// Foreground work borrows the app's presenter. A headless callback owns a
/// container until all work completes, including exceptional completion.
Future<T> withFamilyChatPresenter<T>(
  Future<T> Function(AndroidFamilyChatPresenter presenter) operation, {
  AndroidFamilyChatPresenter? presenter,
  ProviderContainer Function()? createHeadlessContainer,
}) async {
  if (presenter != null) return operation(presenter);
  final container = createHeadlessContainer?.call() ?? ProviderContainer();
  try {
    return await operation(container.read(familyChatPresenterProvider));
  } finally {
    container.dispose();
  }
}

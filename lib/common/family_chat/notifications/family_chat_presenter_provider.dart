import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/providers/local_notifications_controller_provider.dart';
import '../../../core/notifications/providers/notifications_controller_provider.dart';
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

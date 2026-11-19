import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/providers/local_notifications_controller_provider.dart';
import 'family_chat_presenter.dart';

final familyChatPresenterProvider = Provider<AndroidFamilyChatPresenter>(
  (ref) => AndroidFamilyChatPresenter(
    controller: ref.watch(localNotificationsControllerProvider),
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

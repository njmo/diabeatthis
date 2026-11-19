import 'package:diabeatthis/app/providers/app_lifecycle_state_provider.dart';
import 'package:diabeatthis/core/notifications/controllers/local_notifications_controller.dart';
import 'package:diabeatthis/core/notifications/providers/local_notifications_controller_provider.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _LocalController extends LocalNotificationsController {
  _LocalController() : super(FlutterLocalNotificationsPlugin());
  final cancelled = <int>[];
  int clearCount = 0;
  @override
  Future<void> cancel(int id, {String? tag}) async {
    cancelled.add(id);
  }

  @override
  Future<void> cancelAll() async {
    clearCount++;
  }

  @override
  Future<Iterable<int>> get pending async => [42];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'UI and foreground notifications honor the same Riverpod local controller',
    () async {
      final local = _LocalController();
      final container = ProviderContainer(
        overrides: [
          localNotificationsControllerProvider.overrideWithValue(local),
          appLifecycleProvider.overrideWithValue(AppLifecycleState.resumed),
        ],
      );
      addTearDown(container.dispose);
      final ui = container.read(notificationsControllerUiProvider);
      final foreground = container.read(
        notificationsControllerForegroundProvider,
      );
      await ui.cancel(7);
      await foreground.cancel(8);
      await ui.cancelAll();
      expect(local.cancelled, [7, 8]);
      expect(local.clearCount, 1);
      expect(await foreground.pending, [42]);
    },
  );
}

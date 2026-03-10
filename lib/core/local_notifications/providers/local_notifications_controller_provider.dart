import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../service/local_notifications_controller.dart';
import 'local_notifications_plugin_provider.dart';

part 'local_notifications_controller_provider.g.dart';

@Riverpod(keepAlive: true)
LocalNotificationsController localNotificationsController(Ref ref) {
  final plugin = ref.watch(localNotificationsPluginProvider);
  return LocalNotificationsController(plugin);
}
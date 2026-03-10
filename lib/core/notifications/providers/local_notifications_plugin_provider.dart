import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'local_notifications_plugin_provider.g.dart';

@Riverpod(keepAlive: true)
FlutterLocalNotificationsPlugin localNotificationsPlugin(Ref ref)
{
  final localNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  return localNotificationsPlugin;
}
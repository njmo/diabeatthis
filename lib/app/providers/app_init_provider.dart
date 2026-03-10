import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../init/foreground_task.dart' as foreground_task;
import '../init/local_notifications.dart' as local_notifications;

part 'app_init_provider.g.dart';

@Riverpod(keepAlive: true)
Future<void> appInit(Ref ref) async {
  await local_notifications.init(ref);
  await foreground_task.init();
}




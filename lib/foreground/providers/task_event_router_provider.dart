import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../event/router/task_event_router.dart';

part 'task_event_router_provider.g.dart';

@Riverpod(keepAlive: true)
TaskEventRouter taskEventRouter(Ref ref) => TaskEventRouter();
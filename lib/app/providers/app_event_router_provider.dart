import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../event/app/app_event_router.dart';

part 'app_event_router_provider.g.dart';

@Riverpod(keepAlive: true)
AppEventRouter appEventRouter(Ref ref) => AppEventRouter();
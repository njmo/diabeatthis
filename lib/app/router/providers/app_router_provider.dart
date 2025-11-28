import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../app_router.dart';
import '../guards/nightscout_config_guard.dart';

part 'app_router_provider.g.dart';

@riverpod
AppRouter appRouter(Ref ref)
{
  final guard = NightscoutGuard(ref);
  final appRouter = AppRouter(guard);
  return appRouter;
}
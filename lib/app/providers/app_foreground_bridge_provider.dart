import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../lifecycle/app_foreground_bridge.dart';

part 'app_foreground_bridge_provider.g.dart';

@Riverpod(keepAlive: true)
AppForegroundBridge appForegroundBridge(Ref ref) => AppForegroundBridge();
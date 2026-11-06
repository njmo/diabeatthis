import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_foreground_bridge_provider.dart';

final stopPatientRuntimeProvider = Provider<Future<void> Function()>(
  (ref) => () async {
    final bridge = ref.read(appForegroundBridgeProvider);
    if (await bridge.isServiceRunning()) await bridge.controller.stop();
  },
);

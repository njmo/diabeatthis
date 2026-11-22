import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';
import 'app/lifecycle/app_foreground_bridge.dart';
import 'app/providers/app_foreground_bridge_provider.dart';
import 'app/router/observers/riverpod_debug_observer.dart';
import 'debug/debug_treatment_fab.dart';
import 'debug/debug_treatment_foreground.dart';
import 'features/dashboard/presentation/screens/dashboard_page.dart';
import 'foreground/service/foreground_service_controller.dart';

Future<void> main() async {
  if (!kDebugMode) {
    throw StateError('The treatment simulator requires a Flutter debug build.');
  }
  final container = ProviderContainer(
    observers: [RiverpodDebugObserver(env: 'ui')],
    overrides: [
      appForegroundBridgeProvider.overrideWith(
        (ref) => AppForegroundBridge(
          controller: ForegroundServiceController(
            taskCallback: startDebugTreatmentForeground,
          ),
        ),
      ),
      dashboardSecondaryActionProvider.overrideWithValue(
        const DebugTreatmentFab(),
      ),
    ],
  );
  await bootstrap(() => const MyApp(), container: container);
}

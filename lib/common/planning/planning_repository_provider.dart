import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_mode/application_device_mode.dart';
import 'local_planning_repository.dart';
import 'planning_repository.dart';

/// Caregiver form scopes override this port with authenticated cloud proposals.
final planningRepositoryProvider = Provider<PlanningRepository>((ref) {
  final mode = ref.exists(applicationDeviceModeProvider)
      ? ref.read(applicationDeviceModeProvider).asData?.value
      : null;
  if (mode == ApplicationDeviceMode.caregiver) {
    throw StateError(
      'Caregiver planning requires an authenticated family scope',
    );
  }
  return LocalPlanningRepository(ref);
});

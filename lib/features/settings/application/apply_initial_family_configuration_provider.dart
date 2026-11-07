import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../common/family_sync/enable_initial_family_sharing.dart';
import 'apply_initial_configuration_use_case.dart';

/// Same setup pipeline, with sharing committed before setup completion is saved.
final applyInitialFamilyConfigurationProvider = Provider(
  (ref) => ApplyInitialConfigurationUseCase(
    ref,
    ref.read(enableInitialFamilySharingProvider),
  ),
);

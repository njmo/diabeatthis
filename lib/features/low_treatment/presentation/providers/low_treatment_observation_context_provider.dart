import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/low_treatment_observation_context_provider.dart';

/// Optional observations load separately so recording treatment stays available.
final lowTreatmentObservationContextProvider = FutureProvider.autoDispose(
  (ref) =>
      ref.watch(loadLowTreatmentObservationContextUseCaseProvider)(clock.now()),
);

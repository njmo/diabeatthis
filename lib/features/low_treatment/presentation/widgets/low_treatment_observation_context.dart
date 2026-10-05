import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/low_treatment_observation_context_provider.dart';
import 'low_treatment_observation_facts.dart';

class LowTreatmentObservationContext extends ConsumerWidget {
  const LowTreatmentObservationContext({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(lowTreatmentObservationContextProvider)
        .when(
          data: (data) => LowTreatmentObservationFacts(data: data),
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        );
  }
}

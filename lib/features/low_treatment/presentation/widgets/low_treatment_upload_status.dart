import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../application/resolve_low_treatment_upload_status_use_case.dart';
import '../../data/providers/low_treatment_upload_provider.dart';

class LowTreatmentUploadStatus extends ConsumerWidget {
  const LowTreatmentUploadStatus({super.key, required this.mealId});
  final int mealId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref
        .watch(lowTreatmentUploadDisplayStatusProvider(mealId))
        .asData
        ?.value;
    if (status == null) return const SizedBox.shrink();
    final message = switch (status) {
      LowTreatmentUploadDisplayStatus.paused =>
        context.lang.lowTreatmentUploadPaused,
      LowTreatmentUploadDisplayStatus.sent =>
        context.lang.lowTreatmentUploadSent,
      LowTreatmentUploadDisplayStatus.cancelled =>
        context.lang.lowTreatmentUploadCancelled,
      LowTreatmentUploadDisplayStatus.verifying =>
        context.lang.lowTreatmentUploadVerifying,
      LowTreatmentUploadDisplayStatus.queued =>
        context.lang.lowTreatmentUploadQueued,
    };
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(message, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

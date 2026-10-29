import 'package:clock/clock.dart';

import '../../../../common/temporary_targets/temp_target_operation.dart';
import 'nightscout_temp_target_writer.dart';
import 'temp_target_operation_repository.dart';

/// Resolves uncertain writes by reading Nightscout. It never repeats a POST.
class TempTargetOperationReconciler {
  const TempTargetOperationReconciler(this.operations, this.writer);

  final TempTargetOperationRepository operations;
  final NightscoutTempTargetWriter writer;

  Future<void> reconcile(String source, String token) async {
    for (final operation in await operations.unresolvedSends()) {
      if (operation.source != source) continue;
      final attempted = operation.attemptedTarget;
      if (attempted == null) continue;
      if (!attempted.until.isAfter(clock.now())) {
        await operations.completeOperation(operation.requestId);
        continue;
      }
      try {
        final confirmed = operation.kind == TempTargetOperationKind.start
            ? await writer.findCreated(attempted, token)
            : null;
        final found = operation.kind == TempTargetOperationKind.start
            ? confirmed != null
            : await writer.containsStop(source, token, operation.stoppedAt!);
        if (found) {
          await operations.markSent(
            operation.requestId,
            confirmed: operation.kind == TempTargetOperationKind.start
                ? attempted.withNightscoutId(confirmed!['_id'] as String?)
                : null,
          );
        } else {
          await operations.markUnknownResult(operation.requestId);
        }
      } catch (_) {
        // An unavailable read cannot establish whether a preceding POST arrived.
        await operations.markUnknownResult(operation.requestId);
      }
    }
  }
}

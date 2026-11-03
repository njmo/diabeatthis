import 'package:clock/clock.dart';

import '../../../features/low_treatment/data/providers/low_treatment_upload_provider.dart';
import '../../runtime/task_cancelled_exception.dart';
import '../base/runtime_context.dart';
import '../base/workflow_task.dart';

class LowTreatmentUploadTask extends WorkflowTask {
  const LowTreatmentUploadTask();

  @override
  Future<void> run(RuntimeContext context) async {
    while (!context.isCancelled) {
      try {
        await context.container.read(processLowTreatmentUploadsUseCaseProvider)(
          clock.now(),
        );
      } on TaskCancelledException {
        rethrow;
      } catch (error) {
        context.log('Low treatment upload deferred: ${error.runtimeType}');
      }
      await context.withWaitScope(
        (scope) => scope.any<void>([
          scope.wallClockWaitUntilHandle(
            clock.now().add(const Duration(seconds: 15)),
          ),
        ]),
      );
    }
  }
}

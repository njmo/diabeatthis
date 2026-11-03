import 'dart:async';

import 'package:diabeatthis/common/handoff/controllers/handoff_controller.dart';
import 'package:diabeatthis/common/handoff/handoff_gateway.dart';
import 'package:diabeatthis/core/domain/model/treatment_base.dart';
import 'package:diabeatthis/features/low_treatment/data/providers/low_treatment_aaps_provider.dart';
import 'package:diabeatthis/features/low_treatment/data/providers/low_treatment_handoff_provider.dart';
import 'package:diabeatthis/features/low_treatment/domain/models/low_treatment_handoff_match.dart';
import 'package:diabeatthis/features/low_treatment/domain/use_cases/low_treatment_handoff_use_case.dart';
import 'package:diabeatthis/foreground/runtime/task_cancelled_exception.dart';
import 'package:diabeatthis/foreground/task/tasks/low_treatment_handoff_task.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../utils/fake_runtime_harness.dart';

void main() {
  test(
    'recovered foreground match confirms PiP before clearing the pending handoff',
    () {
      fakeAsync((async) {
        final operations = <String>[];
        final useCase = RecoveredPipHandoff(operations);
        final gateway = ForegroundPipGateway(operations);
        final container = ProviderContainer(
          overrides: [
            lowTreatmentHandoffUseCaseProvider.overrideWithValue(useCase),
            lowTreatmentPipControllerProvider.overrideWithValue(
              HandoffController(gateway),
            ),
          ],
        );
        final harness = FakeRuntimeHarness(container: container);
        unawaited(
          const LowTreatmentHandoffTask()
              .run(harness.runtimeContext)
              .catchError((Object error) {
                if (error is! TaskCancelledException) throw error;
              }),
        );
        async.flushMicrotasks();
        expect(operations, ['confirm:lowTreatment:7', 'complete:7']);
        expect(gateway.completed, [true]);
        harness.cancel();
        async.flushMicrotasks();
        container.dispose();
      });
    },
  );
}

class ForegroundPipGateway extends Fake implements HandoffGateway {
  ForegroundPipGateway(this.operations);
  final List<String> operations;
  List<bool>? completed;
  @override
  bool get isSupported => true;
  @override
  Future<void> updateRows(String sessionId, List<bool> completed) async {
    operations.add('confirm:$sessionId');
    this.completed = completed;
  }
}

class RecoveredPipHandoff extends Fake implements LowTreatmentHandoffUseCase {
  RecoveredPipHandoff(this.operations);
  final List<String> operations;
  bool finished = false;
  @override
  Future<List<LowTreatmentHandoffMatch>> reconcile({
    required DateTime now,
    List<Treatment> liveTreatments = const [],
  }) async => finished
      ? []
      : [
          LowTreatmentHandoffMatch(
            mealId: 7,
            suggestionAt: null,
            treatAt: now,
            treatExternalId: 'remote',
          ),
        ];
  @override
  Future<void> markCompleted(int mealId) async {
    operations.add('complete:$mealId');
    finished = true;
  }
}

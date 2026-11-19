import 'dart:async';

import 'package:diabeatthis/common/family_chat/application/family_treatment_consumption_recovery.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'provider replacement for the same UID preserves running work and monotonic retry budget',
    () async {
      var elapsed = 0, calls = 0;
      final gate = Completer<void>();
      final testProvider = Provider((ref) {
        final budgets = ref.watch(familyTreatmentConsumptionBudgetsProvider);
        final budget = budgets.putIfAbsent(
          'child',
          () => FamilyTreatmentConsumptionBudget(
            elapsedMilliseconds: () => elapsed,
          ),
        );
        final worker = FamilyTreatmentConsumptionWorker(
          budget: budget,
          ready: () => true,
          recover: () async {
            calls++;
            await gate.future;
          },
        );
        ref.onDispose(worker.dispose);
        return worker;
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final first = container.read(testProvider).pump();
      container.invalidate(testProvider);
      final replacement = container.read(testProvider);
      expect(identical(replacement.pump(), first), true);
      expect(calls, 1);
      gate.complete();
      await first;
      await replacement.pump();
      expect(calls, 1);
      elapsed = 30000;
      await replacement.pump();
      expect(calls, 2);
    },
  );
  test(
    'repeated lifecycle and session signals share one held attempt',
    () async {
      var elapsed = 0, calls = 0;
      final gate = Completer<void>();
      final worker = FamilyTreatmentConsumptionWorker(
        ready: () => true,
        elapsedMilliseconds: () => elapsed,
        recover: () async {
          calls++;
          await gate.future;
        },
      );
      addTearDown(worker.dispose);
      final first = worker.pump();
      for (var index = 0; index < 100; index++) {
        expect(identical(worker.pump(), first), true);
      }
      elapsed = 30000;
      expect(identical(worker.pump(), first), true);
      expect(calls, 1);
      gate.complete();
      await first;
      await worker.pump();
      expect(calls, 2);
    },
  );

  test(
    'readiness and disposal prevent work, including after a previous attempt',
    () async {
      var ready = false, calls = 0, elapsed = 0;
      final worker = FamilyTreatmentConsumptionWorker(
        ready: () => ready,
        elapsedMilliseconds: () => elapsed,
        recover: () async {
          calls++;
        },
      );
      await worker.pump();
      expect(calls, 0);
      ready = true;
      await worker.pump();
      expect(calls, 1);
      ready = false;
      elapsed = 30000;
      await worker.pump();
      expect(calls, 1);
      worker.dispose();
      ready = true;
      await worker.pump();
      expect(calls, 1);
    },
  );

  test(
    'failures and signal storms respect a monotonic thirty-second budget',
    () async {
      var elapsed = 0, calls = 0;
      final worker = FamilyTreatmentConsumptionWorker(
        ready: () => true,
        elapsedMilliseconds: () => elapsed,
        recover: () async {
          calls++;
          throw StateError('offline');
        },
      );
      addTearDown(worker.dispose);
      await worker.pump();
      expect(calls, 1);
      elapsed = 29999;
      await worker.pump();
      expect(calls, 1);
      elapsed = 30000;
      await worker.pump();
      expect(calls, 2);
      elapsed = -1000;
      await worker.pump();
      expect(calls, 2);
    },
  );
}

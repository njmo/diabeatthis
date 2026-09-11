import 'dart:async';

import 'package:diabeatthis/core/domain/model/bolus_wizard.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_wizard_recorder_provider.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/helpers/record_meal_wizard_link.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../utils/fake_runtime_harness.dart';

void main() {
  for (final lateFailure in [false, true]) {
    test('slow recording releases monitor and handles late '
        '${lateFailure ? 'failure' : 'success'}', () {
      fakeAsync((async) {
        final write = Completer<void>();
        var calls = 0;
        final container = ProviderContainer(
          overrides: [
            mealWizardRecorderProvider.overrideWithValue((_, _, _) {
              calls++;
              return write.future;
            }),
          ],
        );
        final now = DateTime(2026, 9, 11);
        var released = false;
        const RecordMealWizardLink()(
          FakeRuntimeHarness(container: container).runtimeContext,
          BolusWizard(
            nightscoutObjectId: null,
            createdAt: now,
            date: now,
            glucose: 120,
            units: null,
            notes: null,
            calculatorResult: null,
          ),
          7,
        ).then((_) => released = true);
        async.flushMicrotasks();
        expect(released, isFalse);
        async.elapse(const Duration(seconds: 2));
        async.flushMicrotasks();
        expect(released, isTrue);
        expect(write.isCompleted, isFalse);
        if (lateFailure) {
          write.completeError(StateError('late database failure'));
        } else {
          write.complete();
        }
        async.flushMicrotasks();
        expect(calls, 1);
        container.dispose();
      });
    });
  }
}

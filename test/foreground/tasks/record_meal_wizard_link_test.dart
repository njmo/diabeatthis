import 'package:diabeatthis/core/domain/model/bolus_wizard.dart';
import 'package:diabeatthis/features/meals/common/models/meal_wizard_relation_type.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_wizard_recorder_provider.dart';
import 'package:diabeatthis/foreground/task/tasks/meal_monitor_task/helpers/record_meal_wizard_link.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../utils/fake_runtime_harness.dart';

void main() {
  test(
    'foreground recording awaits the selected wizard and preserves add-on role',
    () async {
      final now = DateTime(2026, 9, 11);
      final wizard = BolusWizard(
        nightscoutObjectId: null,
        createdAt: now,
        date: now,
        glucose: 120,
        units: null,
        notes: null,
        calculatorResult: null,
      );
      final calls = <(BolusWizard, int, MealWizardRelationType)>[];
      final container = ProviderContainer(
        overrides: [
          mealWizardRecorderProvider.overrideWithValue((
            wizard,
            meal,
            type,
          ) async {
            await Future<void>.value();
            calls.add((wizard, meal, type));
          }),
        ],
      );
      addTearDown(container.dispose);
      final harness = FakeRuntimeHarness(container: container);
      await const RecordMealWizardLink()(
        harness.runtimeContext,
        wizard,
        7,
        type: MealWizardRelationType.continuation,
      );
      expect(calls, [(wizard, 7, MealWizardRelationType.continuation)]);
    },
  );

  test(
    'a persistence error does not reject an already consumed calculator response',
    () async {
      final now = DateTime(2026, 9, 11);
      final container = ProviderContainer(
        overrides: [
          mealWizardRecorderProvider.overrideWithValue(
            (_, _, _) async => throw StateError('database'),
          ),
        ],
      );
      addTearDown(container.dispose);
      await const RecordMealWizardLink()(
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
      );
    },
  );
}

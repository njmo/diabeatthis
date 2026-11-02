import 'package:diabeatthis/common/meal/meal_add_on_bolus_context.dart';
import 'package:diabeatthis/common/meal/meal_add_on_bolus_progress.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/mappers/bolus_wizard_drift_mapper.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/mappers/manual_bolus_drift_mapper.dart';
import 'package:diabeatthis/core/domain/model/bolus_wizard.dart';
import 'package:diabeatthis/core/domain/model/manual_bolus.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' show DatabaseImpl;
import 'package:diabeatthis/foreground/event/internal/treatment_available_event.dart';
import 'package:diabeatthis/foreground/task/base/workflow_task.dart';

import '../foreground/utils/fake_runtime_harness.dart';

ManualBolus deliveredMealBolus(DateTime wizardAt) => ManualBolus(
  externalId: 'delivery-${wizardAt.millisecondsSinceEpoch}',
  createdAt: wizardAt,
  insulin: 1,
);

Future<void> seedDeliveredMealBolus(DatabaseImpl db, DateTime wizardAt) =>
    db.localMirrorDao.upsertManualBolus(
      deliveredMealBolus(wizardAt).toCompanion(TreatmentsSource.aaps),
    );

Future<MealAddOnBolusContext?> acceptDeliveredMealAddOnBolus(
  DatabaseImpl db,
  int mealId,
  BolusWizard wizard, {
  required DateTime requestedAt,
}) async {
  final stored = await db.localMirrorDao.getBolusWizardsBetween(
    wizard.createdAt,
    wizard.createdAt,
  );
  if (stored.isEmpty) {
    await db.localMirrorDao.upsertBolusWizard(
      wizard.toCompanion(TreatmentsSource.aaps),
    );
  }
  await seedDeliveredMealBolus(db, wizard.createdAt);
  return acceptMealAddOnBolus(db, mealId, wizard, requestedAt: requestedAt);
}

void dispatchDeliveredMealBolus(
  FakeRuntimeHarness harness,
  BolusWizard wizard, {
  InterruptableWorkflowTask? task,
}) {
  final delivery = TreatmentAvailableEvent<ManualBolus>(
    deliveredMealBolus(wizard.createdAt),
  );
  final calculator = TreatmentAvailableEvent<BolusWizard>(wizard);
  if (task == null) {
    harness.dispatchEvent(delivery);
    harness.dispatchEvent(calculator);
  } else {
    harness.dispatchEventToTask(task, delivery);
    harness.dispatchEventToTask(task, calculator);
  }
}

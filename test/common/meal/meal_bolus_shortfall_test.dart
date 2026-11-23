import 'dart:async';

import 'package:diabeatthis/common/meal/meal_bolus_shortfall.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/mappers/bolus_wizard_drift_mapper.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/mappers/manual_bolus_drift_mapper.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../foreground/tasks/meal_monitor_test.dart' show testBolusWizard;
import '../../helpers/delivered_meal_bolus.dart';

void main() {
  test('linked meal warns after a smaller delivery is recorded', () async {
    final db = DatabaseImpl(NativeDatabase.memory());
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });
    final opened = DateTime.utc(2026, 11, 23, 18, 48, 19);
    final mealId = await db
        .into(db.meal)
        .insert(MealCompanion.insert(name: 'Dinner'));
    final wizard = testBolusWizard(createdAt: opened, carbs: 31, insulin: 2);
    await db.localMirrorDao.upsertBolusWizard(
      wizard.toCompanion(TreatmentsSource.aaps),
    );
    final stored = (await db.localMirrorDao.getBolusWizardsBetween(
      opened,
      opened,
    )).single;
    await db.mealWizardLinkDao.link(
      mealId: mealId,
      localWizardId: stored.localId,
      relationType: 'initial',
    );

    final provider = mealBolusShortfallsProvider(mealId);
    final warning = Completer<List<MealBolusShortfall>>();
    final subscription = container.listen(provider, (_, next) {
      final rows = next.value;
      if (rows != null && rows.isNotEmpty && !warning.isCompleted) {
        warning.complete(rows);
      }
    });
    addTearDown(subscription.close);
    expect(await container.read(provider.future), isEmpty);

    final delivery = deliveredMealBolus(opened).copyWith(
      createdAt: opened.add(const Duration(seconds: 50)),
      insulin: 1.5,
    );
    await db.localMirrorDao.upsertManualBolus(
      delivery.toCompanion(TreatmentsSource.aaps),
    );
    expect(await warning.future, [(delivered: 1.5, recommended: 2.0)]);
  });
}

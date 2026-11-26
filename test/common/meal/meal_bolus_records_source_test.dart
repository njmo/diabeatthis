import 'package:diabeatthis/common/meal/meal_bolus_shortfall.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config_provider.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/services/local_mirror_writer.dart';
import 'package:diabeatthis/core/domain/model/manual_bolus.dart';
import 'package:diabeatthis/core/domain/model/treatment_base.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' show DatabaseImpl;
import 'package:diabeatthis/core/drift/database_impl.dart' as drift;
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/foreground/providers/meal_bolus_delivery_history_provider.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../foreground/tasks/meal_monitor_test.dart' show testBolusWizard;

DataSourceConfig _config({required bool mirror}) => DataSourceConfig(
  bgSource: BgSource.cloud,
  treatmentsSource: TreatmentsSource.aaps,
  pumpStatusSource: PumpStatusSource.cloud,
  historySource: HistorySource.cloud,
  mirrorToLocal: mirror,
);

void main() {
  final at = DateTime.utc(2026, 11, 26, 12);
  late DatabaseImpl db;

  setUp(() => db = DatabaseImpl(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<int> linkedMeal(Treatment wizard) async {
    final writer = LocalMirrorWriter(db.localMirrorDao);
    await writer.mirrorTreatments([wizard], TreatmentsSource.aaps);
    final stored = await db.select(db.bolusWizard).getSingle();
    final mealId = await db
        .into(db.meal)
        .insert(drift.MealCompanion.insert(name: 'Lunch'));
    await db.mealWizardLinkDao.link(
      mealId: mealId,
      localWizardId: stored.localId,
      relationType: 'initial',
    );
    return mealId;
  }

  test('a cancelled AAPS bolus shows the cancelled marker', () async {
    final wizard = testBolusWizard(createdAt: at, carbs: 20, insulin: 4);
    final mealId = await linkedMeal(wizard);
    final delivery = ManualBolus(
      externalId: 'delivery',
      createdAt: at.add(const Duration(seconds: 1)),
      insulin: 4,
    );
    final writer = LocalMirrorWriter(db.localMirrorDao);
    await writer.mirrorTreatments([delivery], TreatmentsSource.aaps);
    expect((await readMealBolusRecords(db, mealId)).single.recorded, 4);
    await writer.mirrorTreatments([
      delivery.copyWith(isValid: false),
    ], TreatmentsSource.aaps);
    final record = (await readMealBolusRecords(db, mealId)).single;
    expect(record.recorded, isNull);
    expect(record.cancelled, isTrue);
  });

  test('without the mirror the insulin record comes from history', () async {
    final wizard = testBolusWizard(createdAt: at, carbs: 20, insulin: 4);
    final mealId = await linkedMeal(wizard);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        dataSourceConfigProvider.overrideWithValue(
          AsyncData(_config(mirror: false)),
        ),
        mealBolusDeliveryHistoryProvider.overrideWithValue(
          (_) async => [
            ManualBolus(
              externalId: 'nightscout',
              createdAt: at.add(const Duration(seconds: 30)),
              insulin: 3,
            ),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);
    final provider = mealBolusRecordsProvider(mealId);
    final keepAlive = container.listen(provider, (_, _) {});
    addTearDown(keepAlive.close);
    final records = await container.read(provider.future);
    expect(records.single.recorded, 3);
    expect(records.single.cancelled, isFalse);
    expect(await db.select(db.manualBolus).get(), isEmpty);
  });

  test(
    'a cancelled history bolus marks only the calculator it followed',
    () async {
      final first = testBolusWizard(createdAt: at, carbs: 20, insulin: 4);
      final second = testBolusWizard(
        createdAt: at.add(const Duration(seconds: 20)),
        carbs: 5,
        insulin: 1,
      );
      final writer = LocalMirrorWriter(db.localMirrorDao);
      await writer.mirrorTreatments([first, second], TreatmentsSource.aaps);
      final mealId = await db
          .into(db.meal)
          .insert(drift.MealCompanion.insert(name: 'Lunch'));
      for (final (index, row)
          in (await db.select(db.bolusWizard).get()).indexed) {
        await db.mealWizardLinkDao.link(
          mealId: mealId,
          localWizardId: row.localId,
          relationType: index == 0 ? 'initial' : 'continuation',
        );
      }
      final cancelledBolus = ManualBolus(
        externalId: 'cancelled',
        createdAt: at.add(const Duration(seconds: 25)),
        insulin: 1,
        isValid: false,
      );
      final records = await readMealBolusRecords(
        db,
        mealId,
        history: (_) async => [first, second, cancelledBolus],
      );
      expect(
        records.map((record) => record.cancelled),
        unorderedEquals([false, true]),
      );
      expect(records.singleWhere((record) => record.cancelled).recommended, 1);
    },
  );
}

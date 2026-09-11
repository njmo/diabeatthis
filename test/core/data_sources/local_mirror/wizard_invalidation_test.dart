import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/services/local_mirror_writer.dart';
import 'package:diabeatthis/core/data_sources/nightscout/dto/bolus_wizard_dto.dart';
import 'package:diabeatthis/core/data_sources/nightscout/mappers/bolus_wizard_mapper.dart';
import 'package:diabeatthis/core/domain/model/manual_bolus.dart' as domain;
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/meals/data/repositories/meal_wizard_link_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'conflicting invalidations preserve meal links and do not interrupt the batch',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final writer = LocalMirrorWriter(db.localMirrorDao);
      final first = BolusWizardDto.fromJson({
        '_id': 'ns1',
        'glucose': 120,
        'created_at': '2026-09-11T12:00:00Z',
        'bolusCalculatorResult': {'carbs': 20, 'totalInsulin': 2},
      }).toDomain(remoteSource: 'https://example.com');
      await writer.mirrorTreatments([first], TreatmentsSource.cloud);
      final stored = await db.select(db.bolusWizard).getSingle();
      final meal = await db
          .into(db.meal)
          .insert(MealCompanion.insert(name: 'Lunch', plannedAt: 1000));
      final links = MealWizardLinkRepository(db);
      await links.link(mealId: meal, localWizardId: stored.localId);
      await writer.mirrorTreatments([
        first.copyWith(isValid: false, nightscoutObjectId: 'other'),
        first.copyWith(isValid: false, remoteSource: 'https://other.com'),
        domain.ManualBolus(
          externalId: 'bolus',
          createdAt: first.createdAt.add(const Duration(minutes: 30)),
          insulin: 1,
        ),
      ], TreatmentsSource.cloud);
      expect((await links.forMeal(meal)).single.localWizardId, stored.localId);
      expect(await db.select(db.bolusWizard).get(), hasLength(1));
      expect(await db.select(db.manualBolus).get(), hasLength(1));
      await writer.mirrorTreatments([
        first.copyWith(isValid: false),
      ], TreatmentsSource.cloud);
      expect(await db.select(db.bolusWizard).get(), isEmpty);
      final link = (await links.forMeal(meal)).single;
      expect(link.localWizardId, isNull);
      expect(link.remoteWizardId, 'ns1');
    },
  );
}

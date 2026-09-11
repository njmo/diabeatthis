import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/services/local_mirror_writer.dart';
import 'package:diabeatthis/core/data_sources/nightscout/dto/bolus_wizard_dto.dart';
import 'package:diabeatthis/core/data_sources/nightscout/helpers/nightscout_source_key.dart';
import 'package:diabeatthis/core/data_sources/nightscout/mappers/bolus_wizard_mapper.dart';
import 'package:diabeatthis/core/domain/model/manual_bolus.dart' as domain;
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/meals/data/repositories/meal_wizard_link_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Nightscout namespace removes secrets and preserves server boundaries',
    () {
      expect(
        nightscoutSourceKey(
          'https://user:secret@Example.com/base/?token=secret#fragment',
        ),
        'https://example.com/base',
      );
      expect(
        nightscoutSourceKey('https://example.com:443/'),
        'https://example.com',
      );
      expect(
        nightscoutSourceKey('https://other.example.com'),
        isNot(nightscoutSourceKey('https://example.com')),
      );
      expect(() => nightscoutSourceKey('example.com'), throwsArgumentError);
    },
  );

  test(
    'a wizard conflict preserves following records and successful enrichment updates its meal link',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final meal = await db
          .into(db.meal)
          .insert(MealCompanion.insert(name: 'Lunch', plannedAt: 1000));
      final links = MealWizardLinkRepository(db);
      await links.link(
        mealId: meal,
        remoteWizardId: 'ns1',
        remoteSource: 'https://example.com',
      );
      final writer = LocalMirrorWriter(db.localMirrorDao);
      final first = BolusWizardDto.fromJson({
        '_id': 'ns1',
        'created_at': '2026-09-11T12:00:00Z',
        'glucose': 120,
        'bolusCalculatorResult': {'carbs': 20, 'totalInsulin': 2},
      }).toDomain(remoteSource: 'https://example.com');
      await writer.mirrorTreatments([first], TreatmentsSource.cloud);
      expect((await links.forMeal(meal)).single.localWizardId, isNotNull);
      await writer.mirrorTreatments([
        first.copyWith(nightscoutObjectId: 'conflicting'),
        domain.ManualBolus(
          externalId: 'bolus',
          createdAt: first.createdAt.add(const Duration(minutes: 30)),
          insulin: 1,
        ),
      ], TreatmentsSource.cloud);
      expect(
        (await db.select(db.bolusWizard).get()).single.nightscoutId,
        'ns1',
      );
      expect((await db.select(db.manualBolus).get()).single.insulin, 1);
      await writer.mirrorTreatments([
        first.copyWith(remoteSource: 'https://other.example.com'),
      ], TreatmentsSource.cloud);
      expect(
        (await db.select(db.bolusWizard).get()).single.remoteSource,
        'https://example.com',
      );
      await writer.mirrorTreatments([
        first.copyWith(
          createdAt: first.createdAt.add(const Duration(milliseconds: 1)),
        ),
      ], TreatmentsSource.cloud);
      expect(await db.select(db.bolusWizard).get(), hasLength(1));
    },
  );
}

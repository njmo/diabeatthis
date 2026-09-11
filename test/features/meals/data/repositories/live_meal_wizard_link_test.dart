import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/domain/model/bolus_wizard.dart' as domain;
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/features/meals/common/models/meal_wizard_relation_type.dart';
import 'package:diabeatthis/features/meals/data/domain/use_cases/link_recorded_meal_wizard_use_case.dart';
import 'package:diabeatthis/features/meals/data/repositories/meal_wizard_link_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'live AAPS events without IDs obtain stable links; add-ons share their meal',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final meal = await db
          .into(db.meal)
          .insert(MealCompanion.insert(name: 'Lunch', plannedAt: 1000));
      final time = DateTime(2026, 9, 11, 13, 3);
      final wizard = domain.BolusWizard(
        nightscoutObjectId: null,
        createdAt: time,
        date: time,
        glucose: 120,
        units: null,
        notes: null,
        calculatorResult: null,
      );
      final save = LinkRecordedMealWizardUseCase(
        db,
        loadSource: () async => TreatmentsSource.aaps,
      );
      await save(wizard, meal);
      await save(wizard, meal);
      await save(
        wizard.copyWith(createdAt: time.add(const Duration(minutes: 30))),
        meal,
        type: MealWizardRelationType.continuation,
      );
      final links = await MealWizardLinkRepository(db).forMeal(meal);
      expect(links, hasLength(2));
      expect(links.every((link) => link.localWizardId != null), isTrue);
      expect(
        links.map((link) => link.relationType),
        containsAll(['initial', 'continuation']),
      );
      expect(await db.select(db.bolusWizard).get(), hasLength(2));
    },
  );

  test(
    'cloud events with complete IDs need no local mirror or source configuration',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final meal = await db
          .into(db.meal)
          .insert(MealCompanion.insert(name: 'Lunch', plannedAt: 1000));
      final time = DateTime(2026, 9, 11);
      await LinkRecordedMealWizardUseCase(
        db,
        loadSource: () => throw StateError('must not load'),
      )(
        domain.BolusWizard(
          nightscoutObjectId: 'id',
          remoteSource: 'https://example.com',
          createdAt: time,
          date: time,
          glucose: 120,
          units: null,
          notes: null,
          calculatorResult: null,
        ),
        meal,
      );
      expect(
        (await MealWizardLinkRepository(
          db,
        ).forMeal(meal)).single.remoteWizardId,
        'id',
      );
      expect(await db.select(db.bolusWizard).get(), isEmpty);
    },
  );
}

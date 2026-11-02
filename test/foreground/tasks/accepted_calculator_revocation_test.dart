import 'package:diabeatthis/common/meal/meal_add_on_bolus_progress.dart';
import 'package:diabeatthis/common/meal/meal_bolus_coverage.dart';
import 'package:diabeatthis/common/meal/meal_calculator_submission.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/services/local_mirror_writer.dart';
import 'package:diabeatthis/core/domain/model/manual_bolus.dart';
import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' show DatabaseImpl;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/meal_summary/domain/use_cases/complete_meal_use_case_test.dart'
    show seedCompletionMeal;
import 'meal_monitor_test.dart' show testBolusWizard;

void main() {
  for (final zero in [true, false]) {
    test(
      'accepted calculator loses coverage after ${zero ? 'carbs' : 'delivery'} revocation',
      () async {
        final db = DatabaseImpl(NativeDatabase.memory());
        addTearDown(db.close);
        await seedCompletionMeal(db);
        await db.customUpdate(
          'UPDATE meal_ingredients SET amount = 60 WHERE id = 1',
        );
        final at = DateTime(2026, 11, 2, 17);
        await db.mealDao.updateMealStatus(
          1,
          'eating-then-bolus',
          occurredAt: at,
        );
        await reconcileMealAddOnBolusProgress(db, 1);
        final wizard = testBolusWizard(
          createdAt: at.add(const Duration(seconds: 1)),
          carbs: 12,
          insulin: zero ? 0 : 3,
        );
        final carbs = Treat(
          externalId: 'carbs',
          createdAt: wizard.createdAt.add(const Duration(milliseconds: 830)),
          carbs: 12,
        );
        final actual = ManualBolus(
          externalId: 'actual',
          createdAt: carbs.createdAt,
          insulin: 3,
        );
        final writer = LocalMirrorWriter(db.localMirrorDao);
        await writer.mirrorTreatments([
          wizard,
          if (!zero) actual,
          carbs,
        ], TreatmentsSource.aaps);
        expect(
          (await reconcileMealAddOnBolusProgress(db, 1))!.coveredCarbs,
          12,
        );
        await writer.mirrorTreatments([
          if (zero)
            carbs.copyWith(isValid: false)
          else
            actual.copyWith(isValid: false),
        ], TreatmentsSource.aaps);
        final context = await readMealAddOnBolusContext(db, 1);
        expect((await readMealBolusCoverage(db, 1, context: context)).carbs, 0);
        final revoked = (await reconcileMealAddOnBolusProgress(db, 1))!;
        expect(revoked.coveredCarbs, 0);
        expect(revoked.requestedCarbs, 12);
        expect(revoked.awaitingBolus, isTrue);
        expect(revoked.bolusConfirmed, isFalse);
        await writer.mirrorTreatments([
          if (zero) carbs else actual,
        ], TreatmentsSource.aaps);
        final restored = (await reconcileMealAddOnBolusProgress(db, 1))!;
        expect(restored.coveredCarbs, 12);
        expect(restored.awaitingBolus, isFalse);
        expect(await db.mealWizardLinkDao.forMeal(1), hasLength(1));
      },
    );
  }
  test(
    'persisted calculator matches microsecond input by millisecond identity',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final wizard = testBolusWizard(
        createdAt: DateTime(2026, 11, 2, 17, 0, 0, 123, 456),
        carbs: 12,
        insulin: 0,
      );
      final carbs = Treat(
        externalId: 'carbs',
        createdAt: wizard.createdAt.add(const Duration(milliseconds: 830)),
        carbs: 12,
      );
      await LocalMirrorWriter(
        db.localMirrorDao,
      ).mirrorTreatments([wizard, carbs], TreatmentsSource.aaps);
      expect(
        (await readMealCalculatorSubmission(db, wizard)).isComplete,
        isTrue,
      );
    },
  );
}

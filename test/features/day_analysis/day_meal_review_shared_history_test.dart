import 'package:diabeatthis/core/domain/model/bolus_wizard.dart' as domain;
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/day_analysis/data/providers/day_context_provider.dart';
import 'package:diabeatthis/features/day_analysis/data/providers/day_meal_review_provider.dart';
import 'package:diabeatthis/features/day_analysis/domain/use_cases/build_day_context_use_case.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'build_day_context_use_case_test.dart' show emptyMeals;

void main() {
  test(
    'inline review reuses day wizards and excludes previous-night events',
    () async {
      final date = DateTime(2026, 1, 1);
      domain.BolusWizard wizard(DateTime time) => domain.BolusWizard(
        nightscoutObjectId: time.toString(),
        createdAt: time,
        date: time,
        glucose: 120,
        units: null,
        notes: null,
        calculatorResult: null,
      );
      var reads = 0;
      final build = BuildDayContextUseCase(
        now: () => date.add(const Duration(days: 1)),
        loadGlucose: (_, _) async => [],
        loadTreatments: (_, _) async {
          reads++;
          return [
            wizard(date.subtract(const Duration(hours: 1))),
            wizard(date),
          ];
        },
        loadMeals: (_, _) async => emptyMeals,
        loadLowTreatments: (_, _) async => [],
        loadActivities: (_, _) async => [],
      );
      final db = DatabaseImpl(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          dayContextForDateProvider(
            date,
          ).overrideWith((ref) => build(date: date)),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
      final contextSubscription = container.listen(
        dayContextForDateProvider(date),
        (_, _) {},
      );
      final reviewSubscription = container.listen(
        dayMealReviewProvider(date),
        (_, _) {},
      );
      addTearDown(contextSubscription.close);
      addTearDown(reviewSubscription.close);
      final day = await container.read(dayContextForDateProvider(date).future);
      final review = await container.read(dayMealReviewProvider(date).future);
      expect(day.wizards, hasLength(1));
      expect(review.single.wizards.single.createdAt, date);
      expect(reads, 1);
      container.invalidate(dayMealReviewProvider(date));
      await container.read(dayMealReviewProvider(date).future);
      expect(reads, 1);
    },
  );
}

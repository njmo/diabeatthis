import 'package:clock/clock.dart';
import 'package:diabeatthis/common/history/history_event_type.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/core/data_sources/providers/source_repository_providers.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/activity/data/domain/use_cases/load_low_treatments_for_activity_log_use_case.dart';
import 'package:diabeatthis/features/meals/data/domain/use_cases/analyze_meal_use_case.dart';
import 'package:diabeatthis/features/meals/data/domain/use_cases/load_low_treatments_for_meal_use_case.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/foreground_ui/source_settings_test_doubles.dart';
import '../meals/data/repositories/nutrition_revision_test_fixture.dart';

void main() {
  for (final linkedToActivity in [false, true]) {
    for (final hasSnapshot in [false, true]) {
      test(
        'linked low preserves unknown weights and saved aggregate in analysis; activity=$linkedToActivity snapshot=$hasSnapshot',
        () async {
          final db = DatabaseImpl(NativeDatabase.memory());
          final container = ProviderContainer(
            overrides: [
              databaseProvider.overrideWithValue(db),
              glucoseHistoryRepositoryProvider.overrideWith(
                (ref) async => EmptyGlucoseHistoryRepository(),
              ),
              treatmentsHistoryRepositoryProvider.overrideWith(
                (ref) async => EmptyTreatmentsHistoryRepository(),
              ),
              deviceStatusHistoryRepositoryProvider.overrideWith(
                (ref) async => EmptyDeviceStatusHistoryRepository(),
              ),
            ],
          );
          addTearDown(container.dispose);
          addTearDown(db.close);
          final base = nutritionRevisionMeal();
          final at = base.analysisTime;
          final lowAt = at
              .add(const Duration(minutes: 5))
              .millisecondsSinceEpoch;
          final parent = await db
              .into(db.meal)
              .insert(
                MealCompanion.insert(
                  name: 'Analyzed meal',
                  plannedAt: at.millisecondsSinceEpoch,
                  status: const Value('summarized'),
                ),
              );
          final activity = await db
              .into(db.activity)
              .insert(
                ActivityCompanion.insert(
                  name: 'Walk',
                  percentagePre: 0,
                  percentagePost: 0,
                ),
              );
          final log = await db
              .into(db.activityLog)
              .insert(
                ActivityLogCompanion.insert(
                  activityId: activity,
                  startedAt: at.millisecondsSinceEpoch,
                  endedAt: Value(
                    at.add(const Duration(minutes: 20)).millisecondsSinceEpoch,
                  ),
                ),
              );
          final food = await db
              .into(db.ingredient)
              .insert(
                IngredientCompanion.insert(
                  name: 'Historical sugar',
                  carbsPer100g: 100,
                  fiberPer100g: 0,
                  fatPer100g: 0,
                  proteinPer100g: 0,
                  nutritionConfidence: 1,
                  createdAt: Value(
                    at.subtract(const Duration(days: 1)).millisecondsSinceEpoch,
                  ),
                ),
              );
          final portion = await db
              .into(db.portion)
              .insert(
                PortionCompanion.insert(name: 'Spoon', unitHint: 'spoon'),
              );
          final low = await db
              .into(db.meal)
              .insert(
                MealCompanion.insert(
                  name: 'Recorded rescue',
                  plannedAt: lowAt,
                  purpose: const Value('lowTreatment'),
                  status: const Value('confirmed'),
                  createdAt: Value(lowAt),
                ),
              );
          await db
              .into(db.mealIngredients)
              .insert(
                MealIngredientsCompanion.insert(
                  mealId: low,
                  ingredientId: food,
                  portionId: Value(portion),
                  amount: const Value(2),
                  consumedAmount: const Value(2),
                  quantityConfidence: 1,
                  createdAt: Value(lowAt),
                ),
              );
          await db
              .into(db.lowTreatmentContext)
              .insert(
                LowTreatmentContextCompanion.insert(
                  mealId: Value(low),
                  source: 'manual',
                  relatedMealId: Value(linkedToActivity ? null : parent),
                  relatedActivityLogId: Value(linkedToActivity ? log : null),
                ),
              );
          if (hasSnapshot) {
            await db
                .into(db.mealSnapshot)
                .insert(
                  MealSnapshotCompanion.insert(
                    mealId: low,
                    snapshotType: 'consumed',
                    totalGrams: 7.6,
                    totalCarbsG: 7.6,
                    totalFiberG: 0,
                    totalNetCarbsG: 7.6,
                    totalFatG: 0,
                    totalProteinG: 0,
                    totalCaloriesKcal: 30.4,
                    calculatedAt: Value(lowAt),
                    createdAt: Value(lowAt),
                    updatedAt: Value(lowAt),
                  ),
                );
          }
          final linked = linkedToActivity
              ? await LoadLowTreatmentsForActivityLogUseCase(db: db)(log)
              : await container.read(
                  mealLowTreatmentsForMealUseCaseProvider(parent).future,
                );
          expect(linked, hasLength(1));
          expect(linked.single.ingredientsAvailable, false);
          expect(linked.single.totalNetCarbsG, hasSnapshot ? 7.6 : null);
          final details = base.copyWith(lowTreatments: linked);
          expect(details.lowTreatmentNetCarbsG, hasSnapshot ? 7.6 : null);
          final cutoff = at.add(const Duration(minutes: 30));
          final analysis = (await withClock(
            Clock.fixed(cutoff),
            () => container.read(analyzeMealUseCaseProvider)(
              details,
              asOf: cutoff,
            ),
          ))!;
          final value = analysis.timelineEvents
              .where((event) => event.type == HistoryEventType.lowTreatment)
              .single
              .value!;
          expect(value, contains(lang.amountMissingPortionWeight));
          expect(value, isNot(contains('0 g')));
          expect(
            value,
            contains(hasSnapshot ? '7.6 g netto' : lang.uiUnknownAmount),
          );
        },
      );
    }
  }
}

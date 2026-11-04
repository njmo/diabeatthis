import 'package:diabeatthis/common/nutrition/stable_macro_ceil.dart';
import 'package:diabeatthis/common/platform/aaps_launcher.dart';
import 'package:diabeatthis/common/widgets/meal_start/meal_start_nutrition.dart';
import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' as db;
import 'package:diabeatthis/core/drift/mappers/ingredient_drift_mapper.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/meal_advisor_result_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/meal_snapshot_controller_provider.dart';
import 'package:diabeatthis/features/dashboard/presentation/utils/meal_status_dialog_result_handler.dart';
import 'package:diabeatthis/features/day_analysis/data/repositories/day_analysis_meal_repository.dart';
import 'package:diabeatthis/features/ingredients/data/mappers/ingredient_draft_mapper.dart';
import 'package:diabeatthis/features/meal_advisor/data/providers/get_meal_activity_advice_use_case_provider.dart';
import 'package:diabeatthis/features/meal_advisor/domain/models/meal_activity_windows.dart';
import 'package:diabeatthis/features/meal_advisor/domain/use_cases/get_meal_activity_advice_use_case.dart';
import 'package:diabeatthis/features/meal_advisor/domain/utils/extended_carbs_schedule_settings.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_ingredient_review_nutrition.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../foreground/utils/fake_notifications_controller.dart';
import '../../helpers/localized_material_app.dart';

class NormalizedMealAapsLauncher extends AapsLauncher {
  @override
  Future<AapsLaunchResult> openAaps() async => AapsLaunchResult.opened;
}

void main() {
  for (final boundary in [
    (amount: 1e-15, shown: '1 g'),
    (amount: 30.000001, shown: '31 g'),
  ]) {
    testWidgets(
      'visible carbohydrate boundary preserves real positive amount ${boundary.amount}',
      (tester) async {
        await tester.pumpWidget(
          localizedMaterialApp(
            home: Scaffold(
              body: MealStartNutrition(
                carbsGrams: boundary.amount,
                extendedCarbsGrams: 0,
                scheduleSettings:
                    const ExtendedCarbsScheduleSettings.defaults(),
              ),
            ),
          ),
        );
        expect(find.text(boundary.shown), findsOneWidget);
      },
    );
  }
  for (final mode in ['eu', 'non_eu']) {
    testWidgets(
      '275 g normalized reference keeps 30 g through consumed totals, history, visible review and bolus: $mode',
      (tester) async {
        final database = db.DatabaseImpl(NativeDatabase.memory());
        final notifications = FakeNotificationsController();
        const meal = Meal(
          id: 1,
          name: 'Reviewed plate',
          status: 'waiting-for-bolus',
        );
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(database),
            getMealAdviceProvider(meal).overrideWith((ref) async => null),
            getMealActivityAdviceUseCaseProvider.overrideWithValue(
              GetMealActivityAdviceUseCase(
                loadWindows: () async => const MealActivityWindows(),
                loadActivities: (start, end) async => [],
                onError: (error, stack) =>
                    fail('Unexpected activity read failure: $error'),
              ),
            ),
            notificationsControllerUiProvider.overrideWithValue(notifications),
            aapsLauncherProvider.overrideWithValue(
              NormalizedMealAapsLauncher(),
            ),
          ],
        );
        addTearDown(container.dispose);
        addTearDown(database.close);
        final totalCarbs = mode == 'eu' ? 30.0 : 35.0;
        final ingredient = await database
            .into(database.ingredient)
            .insertReturning(
              db.IngredientCompanion.insert(
                name: 'Plate normalized to 100 g',
                carbsPer100g: totalCarbs / 275 * 100,
                fiberPer100g: 5 / 275 * 100,
                fatPer100g: 0,
                proteinPer100g: 0,
                nutritionConfidence: .6,
                carbsLabelMode: Value(mode),
              ),
            );
        await database
            .into(database.meal)
            .insert(
              db.MealCompanion.insert(
                id: const Value(1),
                name: meal.name,
                plannedAt: 1000,
                status: const Value('waiting-for-bolus'),
                consumptionConfirmedEndedAt: const Value(2000),
              ),
            );
        await database
            .into(database.mealIngredients)
            .insert(
              db.MealIngredientsCompanion.insert(
                mealId: 1,
                ingredientId: ingredient.id,
                amount: const Value(275),
                consumedAmount: const Value(275),
                quantityConfidence: .6,
              ),
            );
        final consumed = (await database.ingredientDao.totalsForMealConsumed(
          1,
        ))!;
        expect(stableMacroCeil(consumed.carbsGrams), totalCarbs.toInt());
        expect(stableMacroCeil(consumed.fiberGrams), 5);
        expect(stableMacroCeil(consumed.netCarbsGrams), 30);
        expect(consumed.totalGrams, 275);
        await container
            .read(mealSnapshotControllerProvider)
            .saveConsumedSnapshot(1);
        final historical = await DayAnalysisMealRepository(
          database,
        ).loadMeal(1);
        expect(historical.macroSource, 'consumed');
        expect(stableMacroCeil(historical.macros!.netCarbsGrams), 30);
        expect(stableMacroCeil(historical.macros!.fiberGrams), 5);
        Future<void>? operation;
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: localizedMaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      MealStartNutrition(
                        carbsGrams: consumed.netCarbsGrams,
                        extendedCarbsGrams: 0,
                        scheduleSettings:
                            const ExtendedCarbsScheduleSettings.defaults(),
                      ),
                      MealIngredientReviewNutrition(
                        ingredient: ingredient.toDomain().toDraft(),
                        totalGrams: 275,
                      ),
                      Consumer(
                        builder: (context, ref, child) => TextButton(
                          onPressed: () {
                            operation = openAapsAfterBolusStatusUpdateIfNeeded(
                              context: context,
                              ref: ref,
                              meal: meal,
                              status: 'waiting-for-bolus',
                            );
                          },
                          child: const Text('Open calculator'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('30 g'), findsNWidgets(2));
        expect(find.text('31 g'), findsNothing);
        expect(find.text('25 g'), findsNothing);
        await tester.ensureVisible(find.text('Open calculator'));
        await tester.tap(find.text('Open calculator'));
        await tester.pumpAndSettle();
        await operation;
        final event =
            notifications.shownEvents.single
                as AapsBolusSuggestionNotificationEvent;
        expect(event.carbs, 30);
        expect(event.extendedCarbs, 0);
        expect(
          (await database.mealDao.getMealById(1))!.status,
          'waiting-for-bolus',
        );
      },
    );
  }
}

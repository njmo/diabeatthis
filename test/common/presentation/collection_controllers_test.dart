import 'package:diabeatthis/common/presentation/collections/controllers/activities_controller.dart';
import 'package:diabeatthis/common/presentation/collections/controllers/activity_logs_controller.dart';
import 'package:diabeatthis/common/presentation/collections/controllers/caregiver_activities_controller.dart';
import 'package:diabeatthis/common/presentation/collections/controllers/caregiver_activity_logs_controller.dart';
import 'package:diabeatthis/common/presentation/collections/controllers/caregiver_ingredients_controller.dart';
import 'package:diabeatthis/common/presentation/collections/controllers/caregiver_meals_controller.dart';
import 'package:diabeatthis/common/presentation/collections/controllers/ingredients_controller.dart';
import 'package:diabeatthis/common/presentation/collections/controllers/meals_controller.dart';
import 'package:diabeatthis/common/presentation/collections/models/collection_state.dart';
import 'package:diabeatthis/common/presentation/collections/views/activities_view.dart';
import 'package:diabeatthis/common/presentation/collections/views/activity_logs_view.dart';
import 'package:diabeatthis/common/presentation/collections/views/ingredients_view.dart';
import 'package:diabeatthis/common/presentation/collections/views/meals_view.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';
import 'family_collection_fixtures.dart';

void main() {
  test(
    'caregiver controllers filter tombstones, query, future logs and expose no deletion',
    () {
      final rows = familyCollectionFixtures();
      rows.add({...rows.first, 'id': '9', 'deleted': true});
      rows.add(
        mirrorRow('activityLogs', 10, {
          'activity_id': 5,
          'started_at': DateTime.now()
              .add(const Duration(days: 1))
              .millisecondsSinceEpoch,
        }),
      );
      final ingredients = CaregiverIngredientsController(
        rows: rows,
        query: 'FARM',
        open: null,
        onRetry: () {},
      );
      expect(ingredients.state.items.single.name, 'Apple');
      expect(
        CaregiverIngredientsController(
          rows: rows,
          query: 'missing',
          open: null,
          onRetry: () {},
        ).state.items,
        isEmpty,
      );
      final meals = CaregiverMealsController(
        rows: rows,
        open: null,
        onRetry: () {},
      );
      expect(meals.delete, isNull);
      final logs = CaregiverActivityLogsController(
        rows: rows,
        activityId: 5,
        open: null,
        onRetry: () {},
      );
      expect(logs.state.items.single.id, 6);
      expect(logs.delete, isNull);
      expect(
        CaregiverActivityLogsController(
          rows: rows,
          activityId: 999,
          open: null,
          onRetry: () {},
        ).state.items,
        isEmpty,
      );
    },
  );

  for (final caregiver in [false, true]) {
    testWidgets(
      'all four common views work with ${caregiver ? 'caregiver' : 'patient'} controllers',
      (tester) async {
        final rows = familyCollectionFixtures();
        var opened = 0;
        var retried = 0;
        void retry() => retried++;
        final familyIngredients = CaregiverIngredientsController(
          rows: rows,
          open: (_) => opened++,
          onRetry: retry,
        );
        final familyMeals = CaregiverMealsController(
          rows: rows,
          open: (_) => opened++,
          onRetry: retry,
        );
        final familyActivities = CaregiverActivitiesController(
          rows: rows,
          open: (_) => opened++,
          onRetry: retry,
        );
        final familyLogs = CaregiverActivityLogsController(
          rows: rows,
          open: (_) => opened++,
          onRetry: retry,
        );
        final ingredients = caregiver
            ? familyIngredients
            : PatientIngredientsController(
                state: familyIngredients.state,
                open: (_) => opened++,
                onLoadMore: () {},
                onRetry: retry,
              );
        final meals = caregiver
            ? familyMeals
            : PatientMealsController(
                state: familyMeals.state,
                open: (_) => opened++,
                onLoadMore: () {},
                onRetry: retry,
                delete: (_) async => false,
              );
        final activities = caregiver
            ? familyActivities
            : PatientActivitiesController(
                state: familyActivities.state,
                open: (_) => opened++,
                onLoadMore: () {},
                onRetry: retry,
              );
        final logs = caregiver
            ? familyLogs
            : PatientActivityLogsController(
                state: familyLogs.state,
                open: (_) => opened++,
                onLoadMore: () {},
                onRetry: retry,
                delete: (_) async => false,
              );
        final search = TextEditingController();
        addTearDown(search.dispose);
        Future<void> mount(Widget child) async {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                databaseProvider.overrideWith(
                  (_) => throw StateError('UI must not open a database'),
                ),
              ],
              child: localizedMaterialApp(home: Scaffold(body: child)),
            ),
          );
          await tester.pumpAndSettle();
        }

        await mount(
          IngredientListContent.controlled(
            controller: ingredients,
            queryController: search,
            onQueryChanged: (_) {},
          ),
        );
        await tester.tap(find.text('Apple'));
        expect(opened, 1);
        await mount(MealListContent.controlled(controller: meals));
        await tester.tap(find.text('Lunch'));
        expect(opened, 2);
        expect(
          find.byType(Dismissible),
          caregiver ? findsNothing : findsOneWidget,
        );
        await mount(ActivitiesView(controller: activities));
        await tester.tap(find.text('Swimming'));
        expect(opened, 3);
        await mount(ActivityLogsView(controller: logs));
        await tester.tap(find.text('Swimming'));
        expect(opened, 4);
        expect(
          find.byType(Dismissible),
          caregiver ? findsNothing : findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        logs.retry();
        expect(retried, 1);
      },
    );
  }

  test('patient pagination delegates to the existing source', () {
    var pages = 0;
    final controller = PatientMealsController(
      state: const CollectionState(items: [], hasMore: true),
      open: null,
      delete: null,
      onLoadMore: () => pages++,
      onRetry: () {},
    );
    controller.loadMore();
    expect(pages, 1);
    expect(controller.state.hasMore, isTrue);
  });
}

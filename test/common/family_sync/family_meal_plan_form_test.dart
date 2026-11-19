import 'package:diabeatthis/common/family_sync/presentation/family_meal_plan_form.dart';
import 'package:diabeatthis/common/ingredient_catalog/catalog_ingredient.dart';
import 'package:diabeatthis/common/ingredient_catalog/catalog_search_page.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_catalog_providers.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_catalog_repository.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_identity.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_search_item.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/core/domain/model/carbs_label_mode.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/meals/presentation/screens/add_meal_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FamilyPlanTestCatalog implements IngredientCatalogRepository {
  int gets = 0;
  @override
  Future<CatalogSearchPage> search({
    required String query,
    required String languageCode,
    int limit = 20,
    String? cursor,
  }) async => CatalogSearchPage(
    releaseId: 'release-test',
    items: [
      const IngredientSearchItem(
        identity: IngredientIdentity(
          source: IngredientSource.firebase,
          sourceId: 'usda_1',
        ),
        name: 'Bread catalog',
      ),
    ],
  );
  @override
  Future<CatalogIngredient> get(
    IngredientIdentity identity, {
    String languageCode = 'en',
  }) async {
    gets++;
    return CatalogIngredient(
      identity: identity,
      name: 'Bread catalog',
      englishName: 'Bread catalog',
      revision: 'a' * 64,
      carbsPer100g: 40,
      fiberPer100g: 2,
      fatPer100g: 1,
      proteinPer100g: 5,
      carbsLabelMode: CarbsLabelMode.eu,
    );
  }
}

void main() {
  testWidgets(
    'caregiver picker combines child ingredients and catalog without local mirroring',
    (tester) async {
      final catalog = FamilyPlanTestCatalog();
      Map<String, dynamic>? sent;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            catalogRepositoryProvider.overrideWithValue(catalog),
            databaseProvider.overrideWith(
              (_) => throw StateError(
                'Caregiver must not access local patient tables',
              ),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: FamilyMealPlanForm(
                rows: const [
                  {
                    'kind': 'ingredients',
                    'id': '42',
                    'revision': 1,
                    'deleted': false,
                    'payload': {
                      'id': 42,
                      'name': 'Bread child',
                      'brand': null,
                      'is_reference': 0,
                      'carbs_per_100g': 40.0,
                      'fat_per_100g': 1.0,
                      'fiber_per_100g': 2.0,
                      'protein_per_100g': 5.0,
                      'nutrition_confidence': .8,
                      'carbs_label_mode': 'eu',
                    },
                  },
                ],
                onSubmit: (values) async {
                  sent = values;
                },
              ),
            ),
          ),
        ),
      );
      final language = AppLocalizations.of(
        tester.element(find.byType(FamilyMealPlanForm)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AddMealPage), findsOneWidget);
      await tester.tap(find.text(language.mealCompositionAddIngredient));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, language.ingredientSearchLabel),
        'Bread',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('Bread child'), findsOneWidget);
      expect(find.text('Bread catalog'), findsOneWidget);
      await tester.tap(find.text('Bread child'));
      await tester.pumpAndSettle();
      expect(catalog.gets, 0);
      await tester.tap(find.text(language.commonSave));
      await tester.pumpAndSettle();
      await tester.tap(find.text(language.mealCompositionAddIngredient));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, language.ingredientSearchLabel),
        'Bread',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bread catalog'));
      await tester.pumpAndSettle();
      expect(catalog.gets, 1);
      await tester.tap(find.text(language.commonSave));
      await tester.pumpAndSettle();
      await tester.tap(find.text(language.mealFlowNextTime));
      await tester.pumpAndSettle();
      expect(find.text(language.mealPlanSpecificTime), findsOneWidget);
      await tester.tap(find.text(language.mealFlowBack));
      await tester.pumpAndSettle();
      await tester.tap(find.text(language.mealPlanTodayWithoutHour));
      await tester.pumpAndSettle();
      expect(find.text(language.mealFlowNextReview), findsNothing);

      await tester.tap(find.text(language.mealFlowBack));
      await tester.pumpAndSettle();
      expect(find.text(language.mealFlowNextTime), findsOneWidget);

      await tester.tap(find.text(language.mealPlanTodayWithoutHour));
      await tester.pumpAndSettle();
      final editTime = find.byTooltip(language.mealEditTime);
      await tester.ensureVisible(editTime);
      await tester.tap(editTime);
      await tester.pumpAndSettle();
      final untimedOption = tester.widget<ListTile>(
        find.widgetWithText(ListTile, language.mealPlanTodayWithoutHour),
      );
      expect(untimedOption.selected, isTrue);
      await tester.tap(find.text(language.mealFlowNextReview));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(language.mealFlowPlan));
      await tester.tap(find.text(language.mealFlowPlan));
      await tester.pumpAndSettle();
      expect(sent, isNotNull);
      expect(sent!['plannedAt'], isNull);
      expect(
        sent!['plannedDay'],
        DateTime.now().toIso8601String().split('T').first,
      );
      expect(sent!['ingredients'], [
        {
          'ingredientId': 42,
          'catalogId': null,
          'catalogRevision': null,
          'grams': 100.0,
        },
        {
          'ingredientId': null,
          'catalogId': 'usda_1',
          'catalogRevision': 'a' * 64,
          'grams': 100.0,
        },
      ]);
    },
  );
}

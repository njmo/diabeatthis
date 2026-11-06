import 'package:diabeatthis/common/family_sync/presentation/family_meal_plan_form.dart';
import 'package:diabeatthis/common/ingredient_catalog/catalog_ingredient.dart';
import 'package:diabeatthis/common/ingredient_catalog/catalog_search_page.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_catalog_providers.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_catalog_repository.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_identity.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_search_item.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/core/domain/model/carbs_label_mode.dart';
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
          overrides: [catalogRepositoryProvider.overrideWithValue(catalog)],
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
      await tester.enterText(
        find.widgetWithText(TextField, language.familyPlanName),
        'Lunch',
      );
      await tester.tap(find.text(language.familyPlanAddIngredient));
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
      await tester.tap(find.text(language.familyPlanAddIngredient));
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
      await tester.ensureVisible(find.text(language.familyPlanSend));
      await tester.tap(find.text(language.familyPlanSend));
      await tester.pumpAndSettle();
      expect(sent, isNotNull);
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

import 'package:diabeatthis/common/family_sync/presentation/family_meal_plan_form.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_catalog_providers.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/widgets/friendly_amount_selector.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/add_meal/meal_review_step.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../family_sync/family_meal_plan_form_test.dart'
    show FamilyPlanTestCatalog;

void main() {
  testWidgets(
    'reselecting catalog grams as child reference preserves mass and canonical identity',
    (tester) async {
      Map<String, dynamic>? sent;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            catalogRepositoryProvider.overrideWithValue(
              FamilyPlanTestCatalog(),
            ),
            databaseProvider.overrideWith(
              (_) => throw StateError('No local database'),
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
                    'id': '5',
                    'payload': {
                      'id': 5,
                      'name': 'Reference child',
                      'is_reference': 1,
                      'carbs_per_100g': 20.0,
                      'fiber_per_100g': 0.0,
                      'protein_per_100g': 2.0,
                      'fat_per_100g': 1.0,
                      'nutrition_confidence': .8,
                      'carbs_label_mode': 'eu',
                    },
                  },
                ],
                initial: {
                  'name': 'Reference lunch',
                  'category': 'lunch',
                  'plannedAt': DateTime.now()
                      .add(const Duration(hours: 1))
                      .millisecondsSinceEpoch,
                  'ingredients': [
                    {
                      'ingredientId': null,
                      'catalogId': 'old',
                      'catalogRevision': 'old',
                      'grams': 150.0,
                    },
                  ],
                },
                onSubmit: (v) async {
                  sent = v;
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final lang = AppLocalizations.of(
        tester.element(find.byType(FamilyMealPlanForm)),
      );
      await tester.tap(find.byTooltip(lang.mealEditIngredientTooltip));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, lang.ingredientSearchLabel),
        'Reference',
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reference child'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FriendlyAmountSelector>(find.byType(FriendlyAmountSelector))
            .value,
        1.5,
      );
      await tester.tap(find.text(lang.commonSave));
      await tester.pumpAndSettle();
      await tester.tap(find.text(lang.mealFlowNextTime));
      await tester.pumpAndSettle();
      await tester.tap(find.text(lang.mealFlowNextReview));
      await tester.pumpAndSettle();
      expect(find.byType(MealReviewStep), findsOneWidget);
      await tester.tap(find.text(lang.mealFlowPlan));
      await tester.pumpAndSettle();
      expect(sent!['ingredients'], [
        {
          'ingredientId': 5,
          'catalogId': null,
          'catalogRevision': null,
          'grams': 150.0,
        },
      ]);
      expect(tester.takeException(), isNull);
    },
  );
}

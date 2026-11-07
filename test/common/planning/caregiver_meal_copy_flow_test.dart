import 'package:diabeatthis/common/family_sync/presentation/family_meal_plan_form.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_catalog_providers.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_draft_provider.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/copied_meal_history_button.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/copied_meal_ingredients_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../family_sync/family_meal_plan_form_test.dart'
    show FamilyPlanTestCatalog;

void main() {
  testWidgets(
    'caregiver uses shared copy preview without accessing patient tables',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            catalogRepositoryProvider.overrideWithValue(
              FamilyPlanTestCatalog(),
            ),
            databaseProvider.overrideWith(
              (_) => throw StateError('No patient database'),
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
                    'kind': 'meals',
                    'id': '4',
                    'payload': {
                      'id': 4,
                      'name': 'Lunch source',
                      'purpose': 'meal',
                      'planned_at': 1,
                    },
                  },
                  {
                    'kind': 'ingredients',
                    'id': '7',
                    'payload': {
                      'id': 7,
                      'name': 'Bread',
                      'carbs_per_100g': 40.0,
                      'fat_per_100g': 1.0,
                      'fiber_per_100g': 0.0,
                      'protein_per_100g': 3.0,
                      'is_reference': 0,
                    },
                  },
                  {
                    'kind': 'mealIngredients',
                    'id': '9',
                    'payload': {
                      'meal_id': 4,
                      'ingredient_id': 7,
                      'amount': 2.0,
                      'portion_id': 8,
                      'grams_per_portion_used': 35.0,
                    },
                  },
                ],
                onSubmit: (_) async {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use a previous meal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lunch source'));
      await tester.pumpAndSettle();
      expect(find.byType(CopiedMealIngredientsPreview), findsOneWidget);
      expect(find.byType(CopiedMealHistoryButton), findsNothing);
      final lang = AppLocalizations.of(
        tester.element(find.byType(CopiedMealIngredientsPreview)),
      );
      await tester.tap(find.text(lang.copiedMealUseIngredients));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(FamilyMealPlanForm));
      // The scoped draft is inside the shared form, not the caregiver local DB.
      final draftContext = tester.element(find.text('Bread').first);
      final draft = ProviderScope.containerOf(
        draftContext,
      ).read(mealDraftProvider);
      expect(draft.mealIngredients.single.amount, 70);
      expect(draft.status, 'planned');
      expect(context.mounted, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}

import 'package:diabeatthis/common/family_sync/presentation/family_ingredient_catalog_section.dart';
import 'package:diabeatthis/common/family_sync/presentation/family_ingredient_details_dialog.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/widgets/meal_macro_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'child catalog row opens read-only nutrition with correct net carbs',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: FamilyIngredientCatalogSection(
                rows: [
                  {
                    'kind': 'ingredients',
                    'id': '1',
                    'deleted': false,
                    'payload': {
                      'id': 1,
                      'name': 'Apple',
                      'is_reference': 0,
                      'carbs_label_mode': 'non_eu',
                      'carbs_per_100g': 15,
                      'fiber_per_100g': 3,
                      'fat_per_100g': 1,
                      'protein_per_100g': 2,
                    },
                  },
                ],
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Apple'));
      await tester.pumpAndSettle();
      expect(find.byType(FamilyIngredientDetailsDialog), findsOneWidget);
      expect(
        tester.widget<MealMacroSummary>(find.byType(MealMacroSummary)).netCarbs,
        12,
      );
      expect(find.byType(TextField), findsNothing);
    },
  );
}

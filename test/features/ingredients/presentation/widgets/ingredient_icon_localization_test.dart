import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/utils/normalize_search_text.dart';
import 'package:diabeatthis/features/ingredients/data/icons/food_icon_assets.dart';
import 'package:diabeatthis/features/ingredients/presentation/widgets/ingredient_icon.dart';
import 'package:diabeatthis/features/ingredients/presentation/widgets/ingredient_icon_picker.dart';
import 'package:diabeatthis/features/ingredients/presentation/widgets/localized_food_icon_name.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every selectable icon has Polish and English labels', () {
    for (final locale in [const Locale('pl'), const Locale('en')]) {
      final language = lookupAppLocalizations(locale);
      for (final id in FoodIconAssets.paths.keys) {
        expect(
          localizedFoodIconName(language, id),
          isNot(language.ingredientUnknownIcon),
          reason: '$locale: $id',
        );
      }
    }
  });

  test('search folds Polish characters, uppercase and decomposed accents', () {
    expect(normalizeSearchText('  MĄKA ŁOSOŚ ŻÓŁĆ '), 'maka losos zolc');
    expect(normalizeSearchText('Cafe\u0301'), 'cafe');
  });

  for (final languageCode in ['pl', 'en']) {
    testWidgets('search and icon labels follow $languageCode locale', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: Locale(languageCode),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: IngredientIconPicker(name: 'Tortilla')),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField),
        languageCode == 'pl' ? 'MAKA OWSIANA' : 'oat flour',
      );
      await tester.pumpAndSettle();
      expect(
        find.byTooltip(languageCode == 'pl' ? 'Mąka owsiana' : 'Oat flour'),
        findsOneWidget,
      );
      final icons = tester
          .widgetList<IngredientIcon>(find.byType(IngredientIcon))
          .toList();
      expect(icons, hasLength(1));
      expect(icons.single.assetPath, 'assets/icons/wicked_food/oat-flour.webp');
      await tester.tap(
        find.byTooltip(languageCode == 'pl' ? 'Wyczyść' : 'Clear'),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
    });
  }
}

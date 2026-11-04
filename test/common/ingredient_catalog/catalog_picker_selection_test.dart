import 'package:diabeatthis/common/ingredient_catalog/ingredient_catalog_providers.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_identity.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_search_item.dart';
import 'package:diabeatthis/common/ingredient_catalog/unified_ingredient_search_use_case.dart';
import 'package:diabeatthis/common/ingredient_catalog/widgets/ingredient_catalog_picker.dart';
import 'package:diabeatthis/common/ingredient_catalog/widgets/ingredient_catalog_results.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'catalog_results_widget_test.dart';

void main() {
  testWidgets(
    'picker prefills query and pins selected remote identity even outside search results',
    (tester) async {
      const selected = IngredientSearchItem(
        identity: IngredientIdentity(
          source: IngredientSource.firebase,
          sourceId: 'selected',
        ),
        name: 'Boiled potatoes',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            unifiedIngredientSearchUseCaseProvider.overrideWithValue(
              UnifiedIngredientSearchUseCase(
                local: WidgetLocalCatalog(),
                catalog: WidgetRemoteCatalog(),
              ),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: IngredientCatalogPicker(
                initialQuery: 'boiled potatoes',
                selectedItem: selected,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'boiled potatoes',
      );
      final tiles = tester
          .widgetList<IngredientCatalogResultTile>(
            find.byType(IngredientCatalogResultTile),
          )
          .toList();
      expect(tiles.first.item.identity, selected.identity);
      expect(tiles.first.selected, isTrue);
      expect(tiles.where((tile) => tile.selected), hasLength(1));
    },
  );
}

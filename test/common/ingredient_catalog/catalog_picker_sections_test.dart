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
    'pinned choice is labelled and separated from the other results',
    (tester) async {
      const selected = IngredientSearchItem(
        identity: IngredientIdentity(
          source: IngredientSource.local,
          sourceId: '99',
        ),
        name: 'Herb sauce',
        localIngredientId: 99,
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
                initialQuery: 'sauce',
                selectedItem: selected,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Selected'), findsOneWidget);
      expect(find.text('Other results'), findsOneWidget);
      final pinned = find.byWidgetPredicate(
        (widget) => widget is IngredientCatalogResultTile && widget.selected,
      );
      expect(
        tester.getBottomLeft(pinned).dy,
        lessThan(tester.getTopLeft(find.text('Other results')).dy),
      );
      expect(
        find.descendant(of: pinned, matching: find.byType(Card)),
        findsNothing,
      );
    },
  );
}

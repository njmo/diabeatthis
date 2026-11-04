import 'package:diabeatthis/common/ingredient_catalog/catalog_search_page.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_catalog_providers.dart';
import 'package:diabeatthis/common/ingredient_catalog/unified_ingredient_search_use_case.dart';
import 'package:diabeatthis/common/ingredient_catalog/widgets/ingredient_catalog_picker.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'catalog_results_widget_test.dart';

class ManualSearchCatalog extends WidgetRemoteCatalog {
  final queries = <String>[];
  @override
  Future<CatalogSearchPage> search({
    required String query,
    required String languageCode,
    int limit = 20,
    String? cursor,
  }) {
    queries.add(query);
    return super.search(
      query: query,
      languageCode: languageCode,
      limit: limit,
      cursor: cursor,
    );
  }
}

void main() {
  testWidgets(
    'manual search replaces AI query and loads unrelated catalog results',
    (tester) async {
      final catalog = ManualSearchCatalog();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            unifiedIngredientSearchUseCaseProvider.overrideWithValue(
              UnifiedIngredientSearchUseCase(
                local: WidgetLocalCatalog(),
                catalog: catalog,
              ),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('pl'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(
              body: IngredientCatalogPicker(
                initialQuery: 'sos ziołowy',
                searchOnly: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'ryż');
      await tester.pumpAndSettle(const Duration(milliseconds: 400));
      expect(catalog.queries.last, 'ryz');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'ryż',
      );
      expect(find.text('Ryż z katalogu'), findsOneWidget);
    },
  );
}

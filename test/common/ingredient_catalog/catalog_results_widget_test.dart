import 'package:diabeatthis/common/ingredient_catalog/catalog_ingredient.dart';
import 'package:diabeatthis/common/ingredient_catalog/catalog_search_page.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_catalog_exception.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_catalog_providers.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_catalog_repository.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_identity.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_search_item.dart';
import 'package:diabeatthis/common/ingredient_catalog/local_ingredient_search_repository.dart';
import 'package:diabeatthis/common/ingredient_catalog/unified_ingredient_search_use_case.dart';
import 'package:diabeatthis/common/ingredient_catalog/widgets/ingredient_catalog_picker.dart';
import 'package:diabeatthis/common/ingredient_catalog/widgets/ingredient_catalog_results.dart';
import 'package:diabeatthis/common/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class WidgetLocalCatalog implements LocalIngredientSearchRepository {
  @override
  Future<List<IngredientSearchItem>> search(
    String query, {
    int limit = 20,
  }) async => [
    const IngredientSearchItem(
      identity: IngredientIdentity(
        source: IngredientSource.local,
        sourceId: '5',
      ),
      name: 'Mój ryż',
      localIngredientId: 5,
    ),
  ];
}

class ReferenceWidgetLocalCatalog implements LocalIngredientSearchRepository {
  @override
  Future<List<IngredientSearchItem>> search(
    String query, {
    int limit = 20,
  }) async => const [
    IngredientSearchItem(
      identity: IngredientIdentity(
        source: IngredientSource.local,
        sourceId: '5',
      ),
      name: 'Zwykły składnik',
      localIngredientId: 5,
    ),
    IngredientSearchItem(
      identity: IngredientIdentity(
        source: IngredientSource.local,
        sourceId: '6',
      ),
      name: 'Dawna porcja referencyjna',
      localIngredientId: 6,
      isReference: true,
    ),
  ];
}

class WidgetRemoteCatalog implements IngredientCatalogRepository {
  bool offline = false;
  @override
  Future<CatalogSearchPage> search({
    required String query,
    required String languageCode,
    int limit = 20,
    String? cursor,
  }) async {
    if (offline) {
      throw const IngredientCatalogException(
        IngredientCatalogFailure.unavailable,
      );
    }
    return CatalogSearchPage(
      items: [
        const IngredientSearchItem(
          identity: IngredientIdentity(
            source: IngredientSource.firebase,
            sourceId: 'usda_123',
          ),
          name: 'Ryż z katalogu',
        ),
      ],
      releaseId: 'r1',
    );
  }

  @override
  Future<CatalogIngredient> get(
    IngredientIdentity identity, {
    String languageCode = 'en',
  }) => throw UnimplementedError();
}

Widget catalogHarness(
  WidgetRemoteCatalog remote,
  Future<void> Function(IngredientSearchItem) onSelected,
) => ProviderScope(
  overrides: [
    unifiedIngredientSearchUseCaseProvider.overrideWithValue(
      UnifiedIngredientSearchUseCase(
        local: WidgetLocalCatalog(),
        catalog: remote,
      ),
    ),
  ],
  child: MaterialApp(
    locale: const Locale('pl'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: IngredientCatalogResults(query: 'ryz', onSelected: onSelected),
    ),
  ),
);

void main() {
  testWidgets(
    'local and cloud rows stay distinct and selection returns the cloud identity',
    (tester) async {
      IngredientSearchItem? selected;
      await tester.pumpWidget(
        catalogHarness(WidgetRemoteCatalog(), (item) async {
          selected = item;
        }),
      );
      await tester.pump();
      expect(find.text('Mój ryż'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 301));
      await tester.pump();
      expect(find.text('Ryż z katalogu'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_outlined), findsOneWidget);
      await tester.tap(find.text('Ryż z katalogu'));
      await tester.pump();
      expect(selected!.identity.source, IngredientSource.firebase);
      expect(selected!.identity.sourceId, 'usda_123');
    },
  );
  testWidgets('offline remote request retains selectable local rows', (
    tester,
  ) async {
    IngredientSearchItem? selected;
    await tester.pumpWidget(
      catalogHarness(WidgetRemoteCatalog()..offline = true, (item) async {
        selected = item;
      }),
    );
    await tester.pump(const Duration(milliseconds: 301));
    await tester.pump();
    expect(find.text('Mój ryż'), findsOneWidget);
    expect(find.textContaining('Katalog jest niedostępny'), findsOneWidget);
    await tester.tap(find.text('Mój ryż'));
    await tester.pump();
    expect(selected!.localIngredientId, 5);
  });

  testWidgets(
    'photo picker excludes synthetic reference portions while the ordinary picker keeps them',
    (tester) async {
      Widget picker(bool includeReferences) => ProviderScope(
        overrides: [
          unifiedIngredientSearchUseCaseProvider.overrideWithValue(
            UnifiedIngredientSearchUseCase(
              local: ReferenceWidgetLocalCatalog(),
              catalog: WidgetRemoteCatalog(),
            ),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('pl'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: IngredientCatalogPicker(
              includeReferenceIngredients: includeReferences,
            ),
          ),
        ),
      );
      await tester.pumpWidget(picker(true));
      await tester.pumpAndSettle();
      expect(find.text('Zwykły składnik'), findsOneWidget);
      expect(find.text('Dawna porcja referencyjna'), findsOneWidget);
      await tester.pumpWidget(picker(false));
      await tester.pumpAndSettle();
      expect(find.text('Zwykły składnik'), findsOneWidget);
      expect(find.text('Dawna porcja referencyjna'), findsNothing);
    },
  );
}

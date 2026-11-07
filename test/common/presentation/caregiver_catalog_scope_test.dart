import 'dart:async';

import 'package:diabeatthis/common/auth/google_account.dart';
import 'package:diabeatthis/common/auth/google_authentication_providers.dart';
import 'package:diabeatthis/common/family_sync/presentation/family_ingredient_catalog_section.dart';
import 'package:diabeatthis/common/family_sync/presentation/family_ingredient_details_dialog.dart';
import 'package:diabeatthis/common/ingredient_catalog/catalog_ingredient.dart';
import 'package:diabeatthis/common/ingredient_catalog/catalog_search_page.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_catalog_providers.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_catalog_repository.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_identity.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_search_item.dart';
import 'package:diabeatthis/core/domain/model/carbs_label_mode.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';
import 'caregiver_audit_fixture.dart';

class AuditIngredientCatalog implements IngredientCatalogRepository {
  final result = Completer<CatalogIngredient>();
  @override
  Future<CatalogSearchPage> search({
    required String query,
    required String languageCode,
    int limit = 20,
    String? cursor,
  }) async => CatalogSearchPage(items: [], releaseId: 'test');
  @override
  Future<CatalogIngredient> get(
    IngredientIdentity identity, {
    String languageCode = 'en',
  }) => result.future;
}

void main() {
  for (final during in ['picker', 'download']) {
    testWidgets('catalog discards old family selection during $during', (
      tester,
    ) async {
      final fixture = CaregiverAuditFixture();
      addTearDown(fixture.close);
      final catalog = AuditIngredientCatalog();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            googleAccountProvider.overrideWith(
              (ref) => Stream.value(const GoogleAccount(uid: 'parent')),
            ),
            catalogRepositoryProvider.overrideWithValue(catalog),
            databaseProvider.overrideWith(
              (ref) => throw StateError('No caregiver patient database'),
            ),
          ],
          child: localizedMaterialApp(
            home: Scaffold(
              body: FamilyIngredientCatalogSection(
                family: fixture.family,
                rows: fixture.family.rows.values.toList(),
                searchOnly: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final state = tester.state<FamilyIngredientCatalogSectionState>(
        find.byType(FamilyIngredientCatalogSection),
      );
      final pending = state.search();
      await tester.pumpAndSettle();
      if (during == 'picker') {
        fixture.family.source = 'new-source';
        fixture.family.notifyListeners();
        await tester.pumpAndSettle();
      }
      const identity = IngredientIdentity(
        source: IngredientSource.firebase,
        sourceId: 'food',
      );
      Navigator.of(
        tester.element(find.byType(FamilyIngredientCatalogSection)),
      ).pop(
        const IngredientSearchItem(identity: identity, name: 'Old selection'),
      );
      await tester.pumpAndSettle();
      if (during == 'download') {
        fixture.family.source = 'new-source';
        fixture.family.notifyListeners();
        catalog.result.complete(
          const CatalogIngredient(
            identity: identity,
            name: 'Old selection',
            englishName: null,
            revision: '1',
            carbsPer100g: 15,
            fiberPer100g: 2,
            fatPer100g: 1,
            proteinPer100g: 1,
            carbsLabelMode: CarbsLabelMode.eu,
          ),
        );
        await tester.pumpAndSettle();
      }
      await pending;
      expect(find.byType(FamilyIngredientDetailsDialog), findsNothing);
      expect(find.text('Old selection'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

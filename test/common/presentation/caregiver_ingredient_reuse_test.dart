import 'package:diabeatthis/common/auth/google_account.dart';
import 'package:diabeatthis/common/auth/google_authentication_providers.dart';
import 'package:diabeatthis/common/family_sync/presentation/family_record_page.dart';
import 'package:diabeatthis/common/family_sync/presentation/models/family_ingredient_details.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/presentation/details/ingredient_details_view.dart';
import 'package:diabeatthis/common/presentation/details/ingredient_preview_controller.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/ingredients/presentation/widgets/ingredient_confidence_banner.dart';
import 'package:diabeatthis/features/ingredients/presentation/widgets/ingredient_history_change_card.dart';
import 'package:diabeatthis/features/ingredients/presentation/widgets/ingredient_meals_section.dart';
import 'package:diabeatthis/features/ingredients/presentation/widgets/ingredient_nutrition_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';
import 'caregiver_audit_fixture.dart';
import 'family_collection_fixtures.dart';

void main() {
  test(
    'published ingredient resolves portions history usages and strips child-only photos',
    () {
      final rows = familyCollectionFixtures()
        ..addAll([
          mirrorRow('portions', 9, {'name': 'Slice', 'unit_hint': ''}),
          {
            'kind': 'ingredientPortions',
            'id': '1/9',
            'payload': {
              'ingredient_id': 1,
              'portion_id': 9,
              'grams_per_portion': 25,
            },
          },
        ]);
      (rows.first['payload'] as Map)['icon_asset_path'] =
          'local-image:child-only';
      final data = FamilyIngredientDetails(rows).build(1)!;
      expect(data.portions.single.gramsPerPortion, 25);
      expect(data.history.single.carbsPer100g, 10);
      expect(data.usages.single.mealId, 2);
      expect(data.ingredient.iconAssetPath, isNull);
      rows.removeWhere((row) => row['kind'] == 'portions');
      expect(FamilyIngredientDetails(rows).build(1), isNull);
    },
  );

  testWidgets(
    'patient and caregiver use identical ingredient view and source-owned meal callback',
    (tester) async {
      final data = FamilyIngredientDetails(
        familyCollectionFixtures(),
      ).build(1)!;
      int? opened;
      Widget app(IngredientPreviewController controller) => ProviderScope(
        overrides: [
          databaseProvider.overrideWith(
            (ref) => throw StateError('Preview must not read local DB'),
          ),
        ],
        child: localizedMaterialApp(
          home: Scaffold(body: IngredientDetailsView(controller: controller)),
        ),
      );
      await tester.pumpWidget(
        app(PatientIngredientPreviewController(data, (id) => opened = id)),
      );
      await tester.pumpAndSettle();
      final patientRect = tester.getRect(find.byType(IngredientNutritionCard));
      await tester.pumpWidget(
        app(
          CaregiverIngredientPreviewController(
            data,
            onOpenMeal: (id) => opened = id,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(IngredientNutritionCard)), patientRect);
      final context = tester.element(find.byType(IngredientDetailsView));
      await tester.tap(find.text(context.lang.ingredientMealsTab));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lunch'));
      expect(opened, 2);
      expect(find.byType(TextField), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'ingredient nested navigation refuses callback from previous family source',
    (tester) async {
      final fixture = CaregiverAuditFixture();
      addTearDown(fixture.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            googleAccountProvider.overrideWith(
              (ref) => Stream.value(const GoogleAccount(uid: 'parent')),
            ),
            databaseProvider.overrideWith(
              (ref) => throw StateError('No patient DB'),
            ),
          ],
          child: localizedMaterialApp(
            home: FamilyRecordPage(
              family: fixture.family,
              kind: 'ingredients',
              id: 1,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(IngredientDetailsView));
      await tester.tap(find.text(context.lang.ingredientMealsTab));
      await tester.pumpAndSettle();
      final oldCallback = tester
          .widget<IngredientMealsSection>(find.byType(IngredientMealsSection))
          .onOpenMeal!;
      fixture.family.source = 'other-child-source';
      oldCallback(2);
      await tester.pumpAndSettle();
      expect(find.byType(FamilyRecordPage), findsOneWidget);
      expect(find.text('Lunch'), findsOneWidget);
      fixture.family.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.byType(IngredientDetailsView), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'partial mirror does not present unassessed catalog confidence as confirmed',
    (tester) async {
      final fixture = CaregiverAuditFixture();
      addTearDown(fixture.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            googleAccountProvider.overrideWith(
              (ref) => Stream.value(const GoogleAccount(uid: 'parent')),
            ),
            databaseProvider.overrideWith(
              (ref) => throw StateError('No patient DB'),
            ),
          ],
          child: localizedMaterialApp(
            home: FamilyRecordPage(
              family: fixture.family,
              kind: 'ingredients',
              id: 1,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(IngredientConfidenceBanner), findsNothing);
      final context = tester.element(find.byType(IngredientDetailsView));
      await tester.tap(find.text(context.lang.ingredientHistoryTab));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<IngredientHistoryChangeCard>(
              find.byType(IngredientHistoryChangeCard),
            )
            .showConfidence,
        isFalse,
      );
      fixture.family.rows['ingredientOrigins/1'] =
          mirrorRow('ingredientOrigins', 1, {
            'ingredient_id': 1,
            'source': 'firebase',
            'source_id': 'food',
            'creation_method': 'catalog',
            'confidence_origin': 'catalog_default',
          });
      fixture.family.notifyListeners();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<IngredientConfidenceBanner>(
              find.byType(IngredientConfidenceBanner),
            )
            .value,
        .5,
      );
      expect(
        tester
            .widget<IngredientHistoryChangeCard>(
              find.byType(IngredientHistoryChangeCard),
            )
            .showConfidence,
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'an open ingredient preview disappears when its family controller is disposed',
    (tester) async {
      final fixture = CaregiverAuditFixture();
      addTearDown(fixture.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            googleAccountProvider.overrideWith(
              (ref) => Stream.value(const GoogleAccount(uid: 'parent')),
            ),
            databaseProvider.overrideWith(
              (ref) => throw StateError('No patient DB'),
            ),
          ],
          child: localizedMaterialApp(
            home: FamilyRecordPage(
              family: fixture.family,
              kind: 'ingredients',
              id: 1,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(IngredientDetailsView), findsOneWidget);
      fixture.family.dispose();
      await tester.pumpAndSettle();
      expect(find.byType(IngredientDetailsView), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

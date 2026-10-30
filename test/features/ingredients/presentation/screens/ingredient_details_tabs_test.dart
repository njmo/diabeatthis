import 'package:diabeatthis/common/nutrition/confidence_level.dart';
import 'package:diabeatthis/common/widgets/value_change_row.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/ingredients/presentation/controllers/ingredient_details_controller.dart';
import 'package:diabeatthis/features/ingredients/presentation/screens/ingredient_page.dart';
import 'package:diabeatthis/features/ingredients/presentation/widgets/ingredient_confidence_banner.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/confidence_slider.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/localized_material_app.dart';

void main() {
  for (final reference in [false, true]) {
    testWidgets(
      'data, edit and confidence-only history work for reference=$reference',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final db = DatabaseImpl(NativeDatabase.memory());
        final container = ProviderContainer(
          overrides: [databaseProvider.overrideWithValue(db)],
        );
        addTearDown(() async {
          container.dispose();
          await db.close();
        });
        final id = (await tester.runAsync(() async {
          final id = await db
              .into(db.ingredient)
              .insert(
                IngredientCompanion.insert(
                  name: reference ? 'Gołąbki bez zawijania' : 'Jogurt',
                  carbsPer100g: 20,
                  fatPer100g: 4,
                  fiberPer100g: 0,
                  proteinPer100g: 5,
                  nutritionConfidence: 0.5,
                  isReference: Value(reference ? 1 : 0),
                ),
              );
          container.listen(ingredientDetailsControllerProvider(id), (_, _) {});
          await container.read(ingredientDetailsControllerProvider(id).future);
          return id;
        }))!;
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: localizedMaterialApp(home: IngredientPage(ingredientId: id)),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(Tab), findsNWidgets(3));
        expect(find.text('Porcje'), findsOneWidget);
        expect(find.byType(IngredientConfidenceBanner), findsOneWidget);
        if (reference) {
          expect(find.text('Wartości referencyjne'), findsOneWidget);
        }
        await tester.tap(find.text('Edytuj'));
        await tester.pumpAndSettle();
        final slider = tester.widget<ConfidenceSlider>(
          find.byType(ConfidenceSlider),
        );
        slider.onChanged(ConfidenceLevel.high);
        await tester.pump();
        await tester.tap(find.text('Zapisz'));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<IngredientConfidenceBanner>(
                find.byType(IngredientConfidenceBanner),
              )
              .value,
          0.75,
        );
        await tester.tap(find.text('Historia'));
        await tester.pumpAndSettle();
        final rows = tester
            .widgetList<ValueChangeRow>(find.byType(ValueChangeRow))
            .toList();
        expect(rows, hasLength(1));
        expect(rows.single.before, 'Średnia');
        expect(rows.single.after, 'Wysoka');
        expect(find.text('Wartości odżywcze bez zmian'), findsOneWidget);
        final stored = await tester.runAsync(
          () => db.ingredientDao.getIngredientById(id),
        );
        expect(stored!.carbsPer100g, 20);
        expect(stored.fatPer100g, 4);
        expect(stored.proteinPer100g, 5);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

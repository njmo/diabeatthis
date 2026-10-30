import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/ingredients/presentation/controllers/ingredient_details_controller.dart';
import 'package:diabeatthis/features/ingredients/presentation/screens/ingredient_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'long ingredient header scrolls on a small screen with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
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
                name:
                    'Kurczak w sosie słodko-kwaśnym z ryżem basmati i warzywami '
                    'przygotowany w szkolnej stołówce na obiad',
                carbsPer100g: 20,
                fatPer100g: 4,
                fiberPer100g: 0,
                proteinPer100g: 5,
                nutritionConfidence: 0.5,
              ),
            );
        container.listen(ingredientDetailsControllerProvider(id), (_, _) {});
        await container.read(ingredientDetailsControllerProvider(id).future);
        return id;
      }))!;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('pl'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: IngredientPage(ingredientId: id),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Wartości odżywcze'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Wartości odżywcze').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

import 'package:diabeatthis/features/ingredients/data/providers/ingredient_provider.dart';
import 'package:diabeatthis/features/ingredients/presentation/widgets/ingredient_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../helpers/localized_material_app.dart';
import '../../../../helpers/regression/catalog_interface_overrides.dart';

void main() {
  testWidgets('typing a search query does not display a selection error', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...catalogSearchInterfaceOverrides(),
          ingredientsByQueryProvider('').overrideWith((_) async => []),
          ingredientsByQueryProvider('twix').overrideWith((_) async => []),
        ],
        child: localizedMaterialApp(
          home: const Scaffold(body: IngredientSearch()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'twix');
    await tester.pumpAndSettle();
    expect(find.text('Wybierz składnik albo dodaj nowy.'), findsNothing);
    expect(
      tester.state<FormFieldState<String>>(find.byType(TextFormField)).hasError,
      isFalse,
    );
  });
}

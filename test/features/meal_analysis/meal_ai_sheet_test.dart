import 'package:diabeatthis/features/meal_analysis/data/prompts/meal_ai_prompt.dart';
import 'package:diabeatthis/features/meal_analysis/data/providers/meal_ai_provider.dart';
import 'package:diabeatthis/features/meal_analysis/presentation/controllers/meal_ai_input_controller.dart';
import 'package:diabeatthis/features/meal_analysis/presentation/widgets/meal_ai_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';
import 'meal_ai_test_fixtures.dart';
import 'meal_ai_workflow_test.dart' show FakeMealAiClient;

void main() {
  testWidgets('opening and inspecting a meal input does not initialize AI', (
    tester,
  ) async {
    final doc = await aiDocument();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mealAiInputProvider(
            1,
          ).overrideWith(() => FixtureMealAiInputController(1, doc)),
          acceptedMealAiProvider.overrideWith((ref, id) async => null),
          mealAiClientProvider.overrideWith(
            (ref) => throw StateError('Do not initialize AI'),
          ),
        ],
        child: localizedMaterialApp(
          home: const Scaffold(body: MealAiSheet(mealId: 1, name: 'Breakfast')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dane wejściowe AI'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SelectableText>(find.byType(SelectableText)).data,
      buildMealAiPrompt(doc, 'pl'),
    );
    await tester.tap(find.byType(CloseButton));
    await tester.pumpAndSettle();
    expect(find.text('Analizuj posiłek'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'invalid JSON is available in the response inspector without saving',
    (tester) async {
      final doc = await aiDocument();
      final client = FakeMealAiClient()..output = '{"schema_version":1';
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mealAiInputProvider(
              1,
            ).overrideWith(() => FixtureMealAiInputController(1, doc)),
            acceptedMealAiProvider.overrideWith((ref, id) async => null),
            mealAiClientProvider.overrideWithValue(client),
          ],
          child: localizedMaterialApp(
            home: const Scaffold(
              body: MealAiSheet(mealId: 1, name: 'Breakfast'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Analizuj posiłek'));
      await tester.pumpAndSettle();
      expect(client.calls, 1);
      await tester.tap(find.text('Odpowiedź AI · JSON'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SelectableText>(find.byType(SelectableText)).data,
        client.output,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

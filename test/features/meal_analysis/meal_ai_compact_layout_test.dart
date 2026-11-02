import 'package:diabeatthis/common/widgets/analysis_error_notice.dart';
import 'package:diabeatthis/common/widgets/keyboard_aware_bottom_sheet.dart';
import 'package:diabeatthis/features/meal_analysis/data/providers/meal_ai_provider.dart';
import 'package:diabeatthis/features/meal_analysis/presentation/controllers/meal_ai_input_controller.dart';
import 'package:diabeatthis/features/meal_analysis/presentation/widgets/meal_ai_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';
import 'meal_ai_test_fixtures.dart';
import 'meal_ai_workflow_test.dart' show FakeMealAiClient;

void main() {
  testWidgets('error panel fits its content and keeps the action visible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(432, 936);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final document = await aiDocument();
    final client = FakeMealAiClient()..output = '{';
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mealAiInputProvider(
            1,
          ).overrideWith(() => FixtureMealAiInputController(1, document)),
          acceptedMealAiProvider.overrideWith((ref, id) async => null),
          mealAiClientProvider.overrideWithValue(client),
        ],
        child: localizedMaterialApp(
          home: const Scaffold(
            body: MealAiButton(mealId: 1, name: 'Breakfast'),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(MealAiButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Analizuj posiłek'));
    await tester.pumpAndSettle();

    expect(find.byType(AnalysisErrorNotice), findsOneWidget);
    expect(
      tester.getSize(find.byType(KeyboardAwareBottomSheet)).height,
      lessThan(500),
    );
    expect(find.text('Analizuj posiłek').hitTestable(), findsOneWidget);
    expect(find.text('Odpowiedź AI · JSON').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

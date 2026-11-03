import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_application_context.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_application_differences.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_recorded_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../helpers/localized_material_app.dart';
import 'meal_review_test.dart' show ReviewTestController;

void main() {
  testWidgets('application context fits a narrow screen with large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 850));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final state = await ReviewTestController().build(1);
    await tester.pumpWidget(
      ProviderScope(
        child: localizedMaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 850),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: MealApplicationContext(state: state),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(MealRecordedActions), findsOneWidget);
    expect(find.byType(MealApplicationDifferences), findsOneWidget);
    expect(find.byType(ExpansionTile), findsNothing);
    expect(find.text('Zmień rodzaj posiłku'), findsNothing);
    expect(find.byIcon(Icons.arrow_downward_rounded), findsNothing);
    expect(find.text('Zapis i synchronizacja'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

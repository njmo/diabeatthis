import 'package:diabeatthis/core/domain/model/extended_carb.dart';
import 'package:diabeatthis/features/meal_analysis/presentation/widgets/meal_outcome_facts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';
import 'build_meal_outcome_context_use_case_test.dart' show at, outcome;

void main() {
  testWidgets(
    'partial outcome shows earlier schedule overlap without implying absorption',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final data = outcome(
        elapsed: 30,
        treatments: [
          ExtendedCarb(
            externalId: 'earlier',
            createdAt: at(-120),
            carbs: 24,
            duration: 14400000,
          ),
        ],
      );
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: SingleChildScrollView(child: MealOutcomeFacts(data: data)),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Kontekst przebiegu posiłku'));
      await tester.pumpAndSettle();
      expect(find.textContaining('obserwacja częściowa'), findsOneWidget);
      expect(find.textContaining('3 g'), findsOneWidget);
      expect(
        find.textContaining('nie oznacza rzeczywistego wchłaniania'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

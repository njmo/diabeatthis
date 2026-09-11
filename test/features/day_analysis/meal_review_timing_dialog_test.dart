import 'package:diabeatthis/features/meals/data/models/meal_review_timing.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_review_timing_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  testWidgets(
    'confirmation requires eating duration and returns entered timing',
    (tester) async {
      MealReviewTiming? result;
      final start = DateTime(2026, 1, 1, 12);
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showDialog<MealReviewTiming>(
                    context: context,
                    builder: (_) => MealReviewTimingDialog(initialTime: start),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Potwierdź i połącz'));
      await tester.pumpAndSettle();
      expect(find.text('Podaj dodatnią liczbę minut.'), findsOneWidget);
      expect(result, isNull);
      await tester.enterText(find.byType(TextFormField).first, '12');
      await tester.tap(find.text('Potwierdź i połącz'));
      await tester.pumpAndSettle();
      expect(result?.startedAt, start);
      expect(result?.timing.eatingMinutes, 12);
    },
  );
}

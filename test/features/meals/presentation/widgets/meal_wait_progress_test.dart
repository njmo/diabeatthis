import 'package:diabeatthis/common/widgets/meal_progress/meal_wait_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('expired waiting stays empty and explicitly elapsed', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MealWaitProgress(
            remaining: Duration(minutes: -3),
            total: Duration(minutes: 15),
          ),
        ),
      ),
    );

    expect(find.text('Czas oczekiwania minął'), findsOneWidget);
    expect(find.text('0 min'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator))
          .value,
      0,
    );
  });

  testWidgets(
    'future timestamp never overfills progress and zero wait is finite',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MealWaitProgress(
              remaining: Duration(minutes: 20),
              total: Duration(minutes: 15),
            ),
          ),
        ),
      );
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        1,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: MealWaitProgress(
              remaining: Duration.zero,
              total: Duration.zero,
            ),
          ),
        ),
      );
      expect(
        tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value,
        0,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

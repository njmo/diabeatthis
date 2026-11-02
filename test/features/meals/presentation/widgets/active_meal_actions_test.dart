import 'package:diabeatthis/common/widgets/meal_progress/active_meal_progress_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/localized_material_app.dart';

void main() {
  testWidgets('eating has explicit actions instead of a generic details menu', (
    tester,
  ) async {
    var additions = 0;
    var earlier = 0;
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: ActiveMealProgressCard(
            name: 'Lunch',
            status: 'Jedzenie',
            schedule: 'Dzisiaj',
            steps: const SizedBox.shrink(),
            actionLabel: 'Zjadłem teraz',
            onAction: () {},
            onInterrupt: () {},
            onEarlierFinished: () => earlier++,
            onAddFood: () => additions++,
          ),
        ),
      ),
    );
    expect(find.text('Szczegóły i działania'), findsNothing);
    await tester.tap(find.text('Dodaj jedzenie'));
    await tester.tap(find.text('Zjadłem wcześniej'));
    expect(additions, 1);
    expect(earlier, 1);
  });

  testWidgets('waiting has one concrete calculator action without duplicates', (
    tester,
  ) async {
    var opens = 0;
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: ActiveMealProgressCard(
            name: 'Lunch',
            status: 'Oczekiwanie na bolus',
            schedule: 'Dzisiaj',
            steps: const SizedBox.shrink(),
            actionLabel: 'Otwórz kalkulator',
            onAction: () => opens++,
            onInterrupt: () {},
          ),
        ),
      ),
    );
    expect(find.text('Szczegóły i działania'), findsNothing);
    expect(find.byType(TextButton), findsNothing);
    expect(find.byType(FilledButton), findsOneWidget);
    await tester.tap(find.text('Otwórz kalkulator'));
    expect(opens, 1);
  });
}

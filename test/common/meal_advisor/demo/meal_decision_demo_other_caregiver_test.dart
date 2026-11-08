import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal_advisor/demo/meal_decision_demo_answer.dart';
import 'package:diabeatthis/common/meal_advisor/demo/meal_decision_demo_controller.dart';
import 'package:diabeatthis/common/meal_advisor/presentation/demo/caregiver_meal_decision_demo_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_decision_demo_controller_test.dart' show demoContainer;

void main() {
  testWidgets(
    'another caregiver sees the owner and then who answered without a reply form',
    (tester) async {
      LanguageStrings.setSelectedLocale(const Locale('en'));
      addTearDown(() => LanguageStrings.setSelectedLocale(null));
      final container = demoContainer();
      addTearDown(container.dispose);
      final controller = container.read(
        mealDecisionDemoControllerProvider.notifier,
      );
      await controller.send('meal', 'Lunch');
      final request = container.read(
        mealDecisionDemoControllerProvider,
      )['meal']!;
      controller.claim('meal', request.id, 'Anna', caregiverId: 'demo-first');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: CaregiverMealDecisionDemoSheet(
                requestKey: 'meal',
                requestId: request.id,
                caregiverName: 'Anna',
                caregiverId: 'demo-second',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Being handled by caregiver Anna'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('Send to child · demo'), findsNothing);
      expect(
        controller.respond(
          'meal',
          request.id,
          answer: MealDecisionDemoAnswer.insulinAndEat,
          minutes: 0,
          caregiverName: 'Anna',
          caregiverId: 'demo-second',
        ),
        isFalse,
      );
      expect(
        controller.respond(
          'meal',
          request.id,
          answer: MealDecisionDemoAnswer.insulinAndEat,
          minutes: 0,
          caregiverName: 'Anna',
          caregiverId: 'demo-first',
        ),
        isTrue,
      );
      await tester.pumpAndSettle();
      expect(find.text('Caregiver Anna has answered'), findsOneWidget);
      expect(find.text('Send to child · demo'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

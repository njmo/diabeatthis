import 'package:diabeatthis/common/meal_advisor/presentation/remote/caregiver_meal_decision_sheet.dart';
import 'package:diabeatthis/common/meal_advisor/presentation/remote/meal_decision_presentation_registry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'notification actions reach an already open request without a second sheet',
    (tester) async {
      late BuildContext current;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              current = context;
              return const Scaffold(body: Text('Existing request'));
            },
          ),
        ),
      );
      var action = '';
      Future<void> handle(String value) async {
        action = value;
      }

      MealDecisionPresentationRegistry.caregiverRequests.add('request');
      final ready = MealDecisionPresentationRegistry.changes.stream.first;
      MealDecisionPresentationRegistry.installCaregiverHandler(
        'request',
        handle,
      );
      await ready;
      addTearDown(() {
        MealDecisionPresentationRegistry.removeCaregiverHandler(
          'request',
          handle,
        );
        MealDecisionPresentationRegistry.caregiverRequests.remove('request');
      });
      await showCaregiverMealDecisionRequest(
        current,
        'request',
        action: 'delegate',
        waitForClose: false,
      );
      expect(action, 'delegate');
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Existing request'), findsOneWidget);
    },
  );
}

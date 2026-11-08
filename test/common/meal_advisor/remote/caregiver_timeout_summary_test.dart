import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal_advisor/presentation/remote/caregiver_meal_decision_timeout.dart';
import 'package:diabeatthis/common/meal_advisor/remote/meal_decision_remote_request.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/localized_material_app.dart';

void main() {
  testWidgets('timeout summary keeps the meal and lets caregiver close', (
    tester,
  ) async {
    var closed = false;
    final request = MealDecisionRemoteRequest({
      'id': 'request',
      'mealId': '1',
      'mealName': 'Lunch',
      'ownerUid': 'child',
      'sourceId': 'source',
      'status': 'expired',
      'deadline': 4000,
      'createdAt': 1000,
    });
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: CaregiverMealDecisionTimeout(
            request: request,
            onClose: () => closed = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lunch'), findsOneWidget);
    final lang = AppLocalizations.of(
      tester.element(find.byType(CaregiverMealDecisionTimeout)),
    );
    expect(
      find.text(lang.mealDecisionCaregiverTimedOutDescription),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.timer_off_outlined), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    expect(closed, isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets('saved fallback outcome remains visible', (tester) async {
    final request = MealDecisionRemoteRequest({
      'id': 'request',
      'mealId': '1',
      'mealName': 'Lunch',
      'ownerUid': 'child',
      'sourceId': 'source',
      'status': 'expired',
      'deadline': 4000,
      'createdAt': 1000,
      'outcome': {
        'source': 'manual',
        'decision': 'insulinAndEat',
        'minutes': null,
      },
    });
    await tester.pumpWidget(
      localizedMaterialApp(
        home: Scaffold(
          body: CaregiverMealDecisionTimeout(request: request, onClose: () {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final lang = AppLocalizations.of(
      tester.element(find.byType(CaregiverMealDecisionTimeout)),
    );
    expect(find.text(lang.uiManualDecision), findsOneWidget);
    expect(find.text(lang.mealDecisionRemoteExpired), findsOneWidget);
  });
}

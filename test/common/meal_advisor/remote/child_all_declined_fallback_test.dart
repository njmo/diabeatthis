import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal_advisor/meal_decision_preferences.dart';
import 'package:diabeatthis/common/meal_advisor/meal_decision_preferences_provider.dart';
import 'package:diabeatthis/common/meal_advisor/presentation/remote/child_meal_decision_fallback_notice.dart';
import 'package:diabeatthis/common/meal_advisor/presentation/remote/child_meal_decision_sheet.dart';
import 'package:diabeatthis/common/meal_advisor/remote/meal_decision_remote_controller.dart';
import 'package:diabeatthis/common/meal_advisor/remote/meal_decision_remote_request.dart';
import 'package:diabeatthis/common/meal_advisor/remote/meal_decision_resolution.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'child_request_timeout_widget_test.dart' show TimeoutInboxController;

void main() {
  for (final scenario in [
    (false, false),
    (true, true),
    (true, false),
    (false, true),
  ]) {
    final manual = scenario.$1;
    final captured = scenario.$2;
    testWidgets(
      'server all-declined outcome resolves before deadline: manual=$manual captured=$captured',
      (tester) async {
        final request = MealDecisionRemoteRequest({
          'id': 'a' * 32,
          'mealId': '1',
          'ownerUid': 'child',
          'sourceId': 'b' * 32,
          'mealName': 'Lunch',
          'createdAt': DateTime.now().millisecondsSinceEpoch,
          'deadline': DateTime.now()
              .add(const Duration(minutes: 5))
              .millisecondsSinceEpoch,
          'status': 'waiting',
          'allowManualDecision': captured,
          'members': [
            {'uid': 'parent', 'displayName': 'Parent', 'status': 'declined'},
          ],
        });
        MealDecisionResolution? result;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              mealDecisionRemoteControllerProvider.overrideWith(
                () => TimeoutInboxController(request),
              ),
              mealDecisionPreferencesProvider.overrideWithValue(
                MealDecisionPreferences(
                  method: MealDecisionMethod.caregiver,
                  allowManualDecision: manual,
                  timeoutFallback: MealDecisionTimeoutFallback.manual,
                ),
              ),
            ],
            child: MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () async =>
                        result = await showChildMealDecisionRequest(
                          context,
                          mealId: 1,
                          mealName: 'Lunch',
                        ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        request.data.addAll({
          'status': 'expired',
          'terminalReason': 'allCaregiversDeclined',
        });
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(find.byType(ChildMealDecisionFallbackNotice), findsOneWidget);
        expect(result, isNull);
        if (manual) {
          await tester.tap(find.text('Continue'));
        } else {
          await tester.pump(const Duration(seconds: 5));
        }
        await tester.pumpAndSettle();
        expect(
          result?.fallback,
          manual && captured
              ? MealDecisionTimeoutFallback.manual
              : MealDecisionTimeoutFallback.app,
        );
        expect(find.byType(ChildMealDecisionSheet), findsNothing);
        expect(request.deadline.isAfter(DateTime.now()), isTrue);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

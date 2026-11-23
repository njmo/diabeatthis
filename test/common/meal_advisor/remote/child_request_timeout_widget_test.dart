import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal_advisor/meal_decision_preferences.dart';
import 'package:diabeatthis/common/meal_advisor/meal_decision_preferences_provider.dart';
import 'package:diabeatthis/common/meal_advisor/presentation/remote/child_meal_decision_sheet.dart';
import 'package:diabeatthis/common/meal_advisor/remote/meal_decision_remote_controller.dart';
import 'package:diabeatthis/common/meal_advisor/remote/meal_decision_remote_request.dart';
import 'package:diabeatthis/common/meal_advisor/remote/meal_decision_resolution.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class TimeoutInboxController extends MealDecisionRemoteController {
  TimeoutInboxController(this.request);
  final MealDecisionRemoteRequest request;
  @override
  MealDecisionRemoteInbox build() =>
      MealDecisionRemoteInbox(requests: [request]);
  @override
  Future<void> refresh() async {}
}

void main() {
  for (final scenario in [(true, true), (false, true), (true, false)]) {
    final manual = scenario.$1;
    final captured = scenario.$2;
    testWidgets(
      'waiting offers close and timeout respects manual permission=$manual captured=$captured',
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
            {'uid': 'parent', 'displayName': 'Parent', 'status': 'available'},
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
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () async {
                      result = await showChildMealDecisionRequest(
                        context,
                        mealId: 1,
                        mealName: 'Lunch',
                      );
                    },
                    child: const Text('Ask'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Ask'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.text('Awaiting a caregiver'), findsOneWidget);
        expect(find.byTooltip('Close'), findsOneWidget);
        final sheet = tester.widget<PopScope>(find.byType(PopScope).last);
        expect(sheet.canPop, isFalse);
        // The test advances real deadline by overriding its server timestamp explicitly.
        final expired = Map<String, dynamic>.from(request.data)
          ..['deadline'] = DateTime.now()
              .subtract(const Duration(seconds: 1))
              .millisecondsSinceEpoch;
        request.data.addAll(expired);
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          result?.fallback,
          manual && captured
              ? MealDecisionTimeoutFallback.manual
              : MealDecisionTimeoutFallback.app,
        );
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(ChildMealDecisionSheet), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

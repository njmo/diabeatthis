import 'package:diabeatthis/common/auth/google_authentication_providers.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal_advisor/meal_decision_preferences.dart';
import 'package:diabeatthis/common/meal_advisor/meal_decision_preferences_provider.dart';
import 'package:diabeatthis/common/meal_advisor/presentation/remote/child_meal_decision_sheet.dart';
import 'package:diabeatthis/common/meal_advisor/remote/meal_decision_remote_controller.dart';
import 'package:diabeatthis/common/meal_advisor/remote/meal_decision_remote_request.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/features/dashboard/data/meal_dialog_controller.dart';
import 'package:diabeatthis/features/dashboard/data/meal_dialog_state.dart';
import 'package:diabeatthis/features/dashboard/presentation/utils/show_meal_status_dialog.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/meal_status_dialog.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_activation_guard_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../demo/meal_decision_demo_real_workflow_test.dart'
    show DemoRealMealTestController;

class InlineRequestInbox extends MealDecisionRemoteController {
  InlineRequestInbox(this.request);
  final MealDecisionRemoteRequest request;

  @override
  MealDecisionRemoteInbox build() =>
      MealDecisionRemoteInbox(requests: [request]);

  @override
  Future<void> refresh() async {}

  void expire() {
    state = MealDecisionRemoteInbox(
      requests: [
        MealDecisionRemoteRequest({
          ...request.data,
          'status': 'expired',
          'terminalReason': 'allCaregiversDeclined',
        }),
      ],
    );
  }
}

class RouteCounter extends NavigatorObserver {
  int pushes = 0;
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushes++;
  }
}

void main() {
  for (final coldStart in [false, true]) {
    testWidgets(
      'caregiver request and fallback stay in the original meal sheet: cold=$coldStart',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
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
          'status': coldStart ? 'expired' : 'waiting',
          if (coldStart) 'terminalReason': 'allCaregiversDeclined',
          'members': [
            {'uid': 'parent', 'displayName': 'Parent', 'status': 'available'},
          ],
        });
        final inbox = InlineRequestInbox(request);
        final mealController = DemoRealMealTestController();
        final observer = RouteCounter();
        final container = ProviderContainer(
          overrides: [
            sharedPrefsProvider.overrideWith((ref) async => prefs),
            googleAccountProvider.overrideWith((ref) => Stream.value(null)),
            mealDecisionRemoteControllerProvider.overrideWith(() => inbox),
            mealDecisionPreferencesProvider.overrideWithValue(
              const MealDecisionPreferences(
                method: MealDecisionMethod.caregiver,
                timeoutFallback: MealDecisionTimeoutFallback.app,
              ),
            ),
            mealDialogControllerProvider(
              1,
              MealDialogStep.choose,
            ).overrideWith(() => mealController),
            mealBlockingActivationProvider(1).overrideWith((ref) async => null),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              navigatorObservers: [observer],
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showMealStatusDialog(
                      context: context,
                      meal: const Meal(id: 1, name: 'Lunch', status: 'planned'),
                      startImmediately: coldStart,
                      initialCaregiverRequestId: coldStart ? request.id : null,
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        expect(observer.pushes, 2); // Home and the one meal sheet.
        if (!coldStart) {
          await tester.tap(find.text('I will eat'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(find.byType(ChildMealDecisionSheet), findsOneWidget);
          expect(find.byType(BottomSheet), findsOneWidget);
          expect(observer.pushes, 2);
          await tester.binding.handlePopRoute();
          await tester.pump();
          expect(find.byType(ChildMealDecisionSheet), findsOneWidget);
          expect(mealController.choices, 0);
          inbox.expire();
          await tester.pump();
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
        }
        expect(mealController.choices, 0);
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        expect(find.byType(ChildMealDecisionSheet), findsNothing);
        expect(find.byType(MealStatusDialog), findsOneWidget);
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(observer.pushes, 2);
        expect(mealController.choices, 1);
        expect(mealController.saves, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

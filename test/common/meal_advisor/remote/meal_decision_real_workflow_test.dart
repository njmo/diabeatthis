import 'package:diabeatthis/common/auth/google_authentication_providers.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal/manual_meal_decision.dart';
import 'package:diabeatthis/common/meal_advisor/meal_decision_preferences.dart';
import 'package:diabeatthis/common/meal_advisor/meal_decision_preferences_provider.dart';
import 'package:diabeatthis/common/meal_advisor/presentation/remote/child_meal_decision_sheet.dart';
import 'package:diabeatthis/common/meal_advisor/remote/meal_decision_resolution.dart';
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

import '../../../features/dashboard/presentation/widgets/meal_start_sheet_test.dart'
    show MealSheetTestController, mealSheetAdviceState;

class MealDecisionWorkflowTestController extends MealSheetTestController {
  int choices = 0;
  @override
  Future<void> chooseEat({ManualMealDecision? manual}) async {
    choices++;
    state = mealSheetAdviceState();
  }
}

void main() {
  for (final immediately in [false, true]) {
    testWidgets(
      'caregiver method can continue with the configured app fallback: immediate=$immediately',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final controller = MealDecisionWorkflowTestController();
        final container = ProviderContainer(
          overrides: [
            sharedPrefsProvider.overrideWith((ref) async => prefs),
            childMealDecisionRequestPresenterProvider.overrideWithValue(
              (context, mealId, name) async => const MealDecisionResolution(
                fallback: MealDecisionTimeoutFallback.app,
              ),
            ),
            googleAccountProvider.overrideWith((ref) => Stream.value(null)),
            mealDecisionPreferencesProvider.overrideWithValue(
              const MealDecisionPreferences(
                method: MealDecisionMethod.caregiver,
              ),
            ),
            mealDialogControllerProvider(
              1,
              MealDialogStep.choose,
            ).overrideWith(() => controller),
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
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showMealStatusDialog(
                      context: context,
                      meal: const Meal(id: 1, name: 'Lunch', status: 'planned'),
                      startImmediately: immediately,
                    ),
                    child: const Text('Open real meal'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open real meal'));
        await tester.pumpAndSettle();
        expect(find.byType(MealStatusDialog), findsOneWidget);
        expect(controller.choices, immediately ? 1 : 0);
        expect(controller.saves, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

import 'dart:async';

import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/features/dashboard/data/meal_dialog_controller.dart';
import 'package:diabeatthis/features/dashboard/data/meal_dialog_state.dart';
import 'package:diabeatthis/features/dashboard/data/utils/meal_advisor.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/meal_status_dialog.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/meal_status_dialog_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../helpers/localized_material_app.dart';

void main() {
  for (final fail in [false, true]) {
    testWidgets(
      'protects pending save and releases dialog after failure=$fail',
      (tester) async {
        const meal = Meal(id: 1, name: 'Obiad', status: 'planned');
        final controller = PendingDecisionController();
        MealStatusDialogResult? result;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              mealDialogControllerProvider(
                1,
                MealDialogStep.choose,
              ).overrideWith(() => controller),
            ],
            child: localizedMaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () async {
                      result = await showDialog<MealStatusDialogResult>(
                        context: context,
                        builder: (_) => const MealStatusDialog(meal: meal),
                      );
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        await tester.tap(find.byType(ElevatedButton));
        await tester.pump();
        expect(controller.saves, 1);
        expect(
          tester
              .widget<TextButton>(find.widgetWithText(TextButton, 'Anuluj'))
              .onPressed,
          isNull,
        );
        expect(
          tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
          isNull,
        );
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
        expect(find.byType(MealStatusDialog), findsOneWidget);
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(MealStatusDialog), findsOneWidget);
        expect(result, isNull);
        if (fail) {
          controller.completion.completeError(StateError('Save failed'));
          await tester.pumpAndSettle();
          expect(find.byType(MealStatusDialog), findsOneWidget);
          expect(
            tester
                .widget<ElevatedButton>(find.byType(ElevatedButton))
                .onPressed,
            isNotNull,
          );
          await tester.tap(find.text('Anuluj'));
          await tester.pumpAndSettle();
          expect(result, isNull);
        } else {
          controller.completion.complete();
          await tester.pumpAndSettle();
          expect(result, isA<MealStatusUpdateResult>());
          final saved = result as MealStatusUpdateResult;
          expect(saved.status, 'waiting-for-bolus');
          expect(saved.alreadySaved, isTrue);
        }
        expect(find.byType(MealStatusDialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

class PendingDecisionController extends MealDialogController {
  final completion = Completer<void>();
  int saves = 0;

  @override
  MealDialogState build(int mId, MealDialogStep initialStep) =>
      MealDialogState.initial(
        MealDialogStep.confirm,
      ).copyWith(advice: MealAdvice(MealDecision.bolusAndEatNow, null));

  @override
  Future<void> cancelAllMealNotifications() async {}

  @override
  Future<void> confirmAdvice() {
    saves++;
    return completion.future;
  }
}

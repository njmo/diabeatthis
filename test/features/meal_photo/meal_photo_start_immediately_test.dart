import 'package:diabeatthis/common/meal/manual_meal_decision.dart';
import 'package:diabeatthis/core/domain/model/meal.dart';
import 'package:diabeatthis/features/dashboard/data/meal_dialog_controller.dart';
import 'package:diabeatthis/features/dashboard/data/meal_dialog_state.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/meal_status_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

class PhotoStartController extends MealDialogController {
  int starts = 0;
  @override
  MealDialogState build(int mId, MealDialogStep initialStep) =>
      MealDialogState.initial(initialStep);
  @override
  Future<void> chooseEat({ManualMealDecision? manual}) async {
    starts++;
  }
}

void main() {
  testWidgets(
    'start from photo enters existing eating flow once across rebuilds',
    (tester) async {
      final controller = PhotoStartController();
      final rebuild = ValueNotifier(0);
      addTearDown(rebuild.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mealDialogControllerProvider(
              1,
              MealDialogStep.choose,
            ).overrideWith(() => controller),
          ],
          child: localizedMaterialApp(
            home: ValueListenableBuilder<int>(
              valueListenable: rebuild,
              builder: (_, _, _) => const MealStatusDialog(
                meal: Meal(id: 1, name: 'Lunch', status: 'planned'),
                startImmediately: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(controller.starts, 1);
      rebuild.value++;
      await tester.pump();
      expect(controller.starts, 1);
    },
  );
}

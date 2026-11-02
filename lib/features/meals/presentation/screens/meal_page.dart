import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../meal_analysis/presentation/widgets/meal_ai_button.dart';
import '../controllers/meal_details_controller.dart';
import 'meal_page_body.dart';

export 'meal_page_body.dart';

@RoutePage()
class MealPage extends ConsumerWidget {
  final int mealId;

  const MealPage({super.key, required this.mealId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(mealDetailsControllerProvider(mealId));

    return Scaffold(
      appBar: AppBar(
        title: Text(context.lang.mealReviewPageTitle),
        actions: [
          if (state.asData?.value.analysis?.hasFullGlucoseWindow == true &&
              state.asData?.value.details.meal.isEaten == true &&
              state.asData?.value.details.meal.isLowTreatment == false)
            MealAiButton(
              mealId: mealId,
              name: state.asData!.value.details.meal.name,
            ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text(context.lang.mealLoadError(error))),
        data: (value) => MealPageBody(state: value),
      ),
    );
  }
}

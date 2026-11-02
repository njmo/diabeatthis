import 'package:diabeatthis/features/meal_analysis/domain/models/recorded_meal_context.dart';
import 'package:flutter_test/flutter_test.dart';

import 'build_before_meal_context_use_case_test.dart'
    show builder, cutoff, macros;

void main() {
  test(
    'preceding meal includes three hours but excludes older meals',
    () async {
      for (final minutes in [179, 180, 181, 600]) {
        final data = await builder(
          meals: [
            RecordedMealContext(
              mealId: 42,
              name: 'Previous',
              eatenAt: cutoff.subtract(Duration(minutes: minutes)),
              snapshot: null,
            ),
          ],
        )(asOf: cutoff, macros: macros);
        expect(data.precedingMeal?.mealId, minutes <= 180 ? 42 : null);
      }
    },
  );
}

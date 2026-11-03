import 'package:diabeatthis/features/meals/domain/use_cases/build_meal_application_review_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../presentation/widgets/meal_details/meal_review_test.dart'
    show ReviewTestController;

void main() {
  test(
    'uses recorded waiting stages and never turns missing calculator data into zero',
    () async {
      final state = await ReviewTestController().build(1);
      final review = const BuildMealApplicationReviewUseCase()(
        state.details,
        state.analysis,
      );
      expect(review.proposedWait, const Duration(minutes: 20));
      expect(review.actualWait, const Duration(minutes: 15));
      expect(review.calculatorCarbs, isNull);
      expect(review.consumedCarbs, isNull);
      final missing = const BuildMealApplicationReviewUseCase()(
        state.details.copyWith(statusHistory: []),
        null,
      );
      expect(missing.actualWait, isNull);
      expect(missing.calculatorCarbs, isNull);
    },
  );
}

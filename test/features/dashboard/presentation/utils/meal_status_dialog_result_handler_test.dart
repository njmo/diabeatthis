import 'package:diabeatthis/features/dashboard/presentation/utils/meal_status_dialog_result_handler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shouldOpenSummaryAfterMealStatusUpdate', () {
    test('opens summary for regular eaten statuses', () {
      expect(shouldOpenSummaryAfterMealStatusUpdate('eaten'), isTrue);
      expect(shouldOpenSummaryAfterMealStatusUpdate('eaten-bolused'), isTrue);
    });

    test('keeps eaten add-on meal on the list until user opens it', () {
      expect(shouldOpenSummaryAfterMealStatusUpdate('eaten-extra'), isFalse);
    });
  });
}

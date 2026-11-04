import 'package:diabeatthis/common/meal/recorded_meal_conversion_unavailable.dart';
import 'package:diabeatthis/common/widgets/meal_completion/meal_conversion_repair_button.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/copied_meal_preview_load_error.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../helpers/localized_material_app.dart';

void main() {
  testWidgets(
    'missing historical grams offer review instead of only retrying',
    (tester) async {
      var retries = 0;
      await tester.pumpWidget(
        ProviderScope(
          child: localizedMaterialApp(
            home: Scaffold(
              body: CopiedMealPreviewLoadError(
                error: RecordedMealConversionUnavailable(),
                stackTrace: StackTrace.current,
                mealId: 4,
                onRetry: () => retries++,
              ),
            ),
          ),
        ),
      );
      expect(find.byType(MealConversionRepairButton), findsOneWidget);
      expect(
        find.textContaining('nie zapisano gramatury porcji'),
        findsOneWidget,
      );
      await tester.tap(find.text('Nie udało się wczytać. Spróbuj ponownie'));
      expect(retries, 1);
    },
  );
}

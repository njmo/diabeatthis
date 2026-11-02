import 'package:diabeatthis/common/widgets/swipeable_cards.dart';
import 'package:diabeatthis/features/meals/presentation/controllers/meal_details_controller.dart';
import 'package:diabeatthis/features/meals/presentation/screens/meal_page.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_technical_section.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../helpers/localized_material_app.dart';
import 'meal_review_test.dart' show ReviewTestController;

void main() {
  testWidgets(
    'six named tabs keep technical records in application context',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            mealDetailsControllerProvider(
              1,
            ).overrideWith(() => ReviewTestController()),
          ],
          child: localizedMaterialApp(home: const MealPage(mealId: 1)),
        ),
      );
      await tester.pumpAndSettle();
      final tabs = tester.widget<SwipeableCards>(find.byType(SwipeableCards));
      expect(tabs.labels, hasLength(6));
      expect(find.text('Obserwacja zakończona'), findsOneWidget);
      expect(find.byType(MealTechnicalSection), findsNothing);
      tester
          .widget<SwipeableCards>(find.byType(SwipeableCards))
          .controller
          .animateTo(5);
      await tester.pumpAndSettle();
      expect(find.byType(MealTechnicalSection), findsOneWidget);
      tester
          .widget<SwipeableCards>(find.byType(SwipeableCards))
          .controller
          .animateTo(0);
      await tester.pumpAndSettle();
      expect(find.byType(MealTechnicalSection), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

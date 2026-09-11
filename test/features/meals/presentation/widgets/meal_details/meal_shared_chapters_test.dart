import 'package:diabeatthis/features/meals/presentation/controllers/meal_details_controller.dart';
import 'package:diabeatthis/features/meals/presentation/screens/meal_page.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/header_status_chip.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/header_status_chip_type.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_technical_section.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../helpers/localized_material_app.dart';
import 'meal_review_test.dart' show ReviewTestController;

void main() {
  testWidgets(
    'chapters and completed status stay visible in both review modes',
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
      void expectSharedContent() {
        for (final title in [
          'Przebieg glikemii',
          'Co mogło mieć znaczenie',
          'Co zostało zjedzone',
          'Decyzje i ich przebieg',
        ]) {
          expect(find.text(title), findsOneWidget);
        }
        expect(
          tester
              .widgetList<HeaderStatusChip>(find.byType(HeaderStatusChip))
              .where((chip) => chip.type == HeaderStatusChipType.analysisReady),
          hasLength(1),
        );
      }

      expectSharedContent();
      expect(find.byType(MealTechnicalSection), findsNothing);
      await tester.tap(find.text('Zaawansowany'));
      await tester.pumpAndSettle();
      expectSharedContent();
      expect(find.byType(MealTechnicalSection), findsOneWidget);
      await tester.tap(find.text('Podstawowy'));
      await tester.pumpAndSettle();
      expectSharedContent();
      expect(find.byType(MealTechnicalSection), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

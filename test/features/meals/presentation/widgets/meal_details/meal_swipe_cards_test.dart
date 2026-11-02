import 'package:diabeatthis/common/widgets/swipeable_cards.dart';
import 'package:diabeatthis/features/meal_analysis/presentation/widgets/before_meal_history_facts.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_before_context_provider.dart';
import 'package:diabeatthis/features/meals/data/providers/similar_meals_provider.dart';
import 'package:diabeatthis/features/meals/presentation/screens/meal_page_body.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_activity_analysis_section.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_charts_section.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_outcome_section.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_portion_overview.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/similar_meals_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../../helpers/localized_material_app.dart';
import '../../../../meal_analysis/build_before_meal_context_use_case_test.dart'
    show builder, cutoff, macros;
import 'meal_review_test.dart' show ReviewTestController;

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets('full meal cards navigate without footer at width $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final state = await ReviewTestController().build(1);
      final before = await builder()(asOf: cutoff, macros: macros);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            similarMealsProvider(
              state.details,
            ).overrideWith((ref) async => null),
            mealBeforeContextProvider((
              details: state.details,
              forceCloud: false,
            )).overrideWith((ref) async => before),
          ],
          child: localizedMaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 850),
                textScaler: const TextScaler.linear(2),
              ),
              child: Scaffold(body: MealPageBody(state: state)),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 / 5'), findsNothing);
      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
      expect(find.byType(MealOutcomeSection), findsOneWidget);
      expect(
        tester
            .widget<MealChartsSection>(find.byType(MealChartsSection))
            .advanced,
        isTrue,
      );
      final cards = tester.widget<SwipeableCards>(find.byType(SwipeableCards));
      Future<void> nextPage(int index) async {
        await tester.drag(find.byType(TabBarView), Offset(-width * .8, 0));
        await tester.pumpAndSettle();
        expect(cards.controller.index, index);
        expect(tester.takeException(), isNull);
      }

      await nextPage(1);
      expect(find.byType(BeforeMealHistoryFacts), findsOneWidget);
      await nextPage(2);
      expect(find.byType(MealPortionOverview), findsOneWidget);
      await nextPage(3);
      expect(find.byType(MealActivityAnalysisSection), findsOneWidget);
      await nextPage(4);
      expect(
        tester
            .widget<SimilarMealsSection>(find.byType(SimilarMealsSection))
            .inline,
        isTrue,
      );
      expect(find.byType(TabBar).hitTestable(), findsOneWidget);
    });
  }
}

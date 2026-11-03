import 'package:diabeatthis/common/widgets/swipeable_cards.dart';
import 'package:diabeatthis/features/meals/data/models/meal_details_data.dart';
import 'package:diabeatthis/features/meals/presentation/controllers/meal_details_controller.dart';
import 'package:diabeatthis/features/meals/presentation/models/meal_page_state.dart';
import 'package:diabeatthis/features/meals/presentation/screens/meal_page.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_origin_card.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_saved_information_card.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../helpers/localized_material_app.dart';
import '../../../fixtures/meal_preview_fixture.dart';
import 'meal_review_test.dart' show ReviewTestController;

class CopiedMealPreviewController extends MealDetailsControllerNotifier {
  @override
  Future<MealPageState> build(int mealId) async {
    final state = await ReviewTestController().build(mealId);
    final copied = mealPreviewFixture(sourceId: 7, summarized: state.details.meal.summarizedAt ?? state.analysis!.mealTime,
      planned: state.details.meal.plannedAt, created: state.details.meal.createdAt, updated: state.details.meal.updatedAt);
    return state.copyWith(details: state.details.copyWith(meal: copied.meal, copySource: const MealCopySourceData(id: 7, name: 'Źródłowy obiad')));
  }
}

void main() {
  testWidgets('origin is confined to the portion tab and save records disappear when leaving application context', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [mealDetailsControllerProvider(1).overrideWith(CopiedMealPreviewController.new)],
      child: localizedMaterialApp(home: const MealPage(mealId: 1)),
    ));
    await tester.pumpAndSettle();
    final controller = tester.widget<SwipeableCards>(find.byType(SwipeableCards)).controller;
    expect(controller.length, 6);
    expect(find.byType(MealSavedInformationCard), findsNothing);
    controller.animateTo(2);
    await tester.pumpAndSettle();
    expect(find.byType(MealOriginCard), findsOneWidget);
    controller.animateTo(5);
    await tester.pumpAndSettle();
    expect(find.byType(MealOriginCard), findsNothing);
    expect(find.byType(MealSavedInformationCard), findsOneWidget);
    controller.animateTo(0);
    await tester.pumpAndSettle();
    expect(find.byType(MealOriginCard), findsNothing);
    expect(find.byType(MealSavedInformationCard), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

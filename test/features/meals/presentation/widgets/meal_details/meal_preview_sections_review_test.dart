import 'package:diabeatthis/common/widgets/nutrition_summary_metric.dart';
import 'package:diabeatthis/features/meals/common/widgets/meal_save_timeline.dart';
import 'package:diabeatthis/features/meals/data/models/meal_details_data.dart';
import 'package:diabeatthis/features/meals/presentation/models/meal_page_state.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_application_context.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_origin_card.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_portion_overview.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_details/meal_saved_information_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../helpers/localized_material_app.dart';
import '../../../fixtures/meal_preview_fixture.dart';

void main() {
  testWidgets('a copied origin appears before the portion and not in application decisions', (tester) async {
    final details = mealPreviewFixture(sourceId: 7, source: const MealCopySourceData(id: 7, name: 'Źródłowy obiad'));
    await tester.pumpWidget(ProviderScope(child: localizedMaterialApp(home: Scaffold(body: SingleChildScrollView(child: Column(children: [
      MealPortionOverview(details: details), MealApplicationContext(state: MealPageState(details: details)),
    ]))))));
    await tester.pumpAndSettle();
    expect(find.byType(MealOriginCard), findsOneWidget);
    expect(find.text('Na podstawie posiłku: Źródłowy obiad'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Pochodzenie posiłku')).dy, lessThan(tester.getTopLeft(find.text('Planowana porcja')).dy));
    expect(find.descendant(of: find.byType(MealApplicationContext), matching: find.byType(MealOriginCard)), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final synced in [true, false]) {
    testWidgets('save timeline retains metadata without metric boxes at large text (synced=$synced)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 850));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final at = DateTime(2026, 11, 3, 12);
      final details = mealPreviewFixture(synced: synced, updated: at.add(const Duration(minutes: 30)),
        decision: mealPreviewDecision(created: at.add(const Duration(minutes: 1))));
      await tester.pumpWidget(localizedMaterialApp(home: MediaQuery(
        data: const MediaQueryData(size: Size(320, 850), textScaler: TextScaler.linear(2)),
        child: Scaffold(body: SingleChildScrollView(child: MealSavedInformationCard(state: MealPageState(details: details)))),
      )));
      await tester.pumpAndSettle();
      expect(find.byType(MealSaveTimeline), findsOneWidget);
      expect(find.byType(NutritionSummaryMetric), findsNothing);
      expect(find.text('03.11.2026 12:00'), findsOneWidget);
      expect(find.text('03.11.2026 12:01'), findsOneWidget);
      expect(find.text('03.11.2026 12:30'), findsOneWidget);
      expect(find.textContaining('Planowany termin posiłku:'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('missing copy source remains visible without an unusable link', (tester) async {
    final details = mealPreviewFixture(sourceId: 7);
    await tester.pumpWidget(localizedMaterialApp(home: Scaffold(body: MealPortionOverview(details: details))));
    expect(find.text('Skopiowano z posiłku #7; źródło nie jest już dostępne.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

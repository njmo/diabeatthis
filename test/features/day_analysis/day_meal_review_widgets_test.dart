import 'package:diabeatthis/core/domain/model/bolus_wizard.dart';
import 'package:diabeatthis/features/day_analysis/data/providers/day_meal_review_provider.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_meal_review_entry.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_recorded_meal.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_meal_link_picker.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_meal_review_section.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_meal_review_tile.dart';
import 'package:diabeatthis/features/meals/common/models/meal_wizard_assignment.dart';
import 'package:diabeatthis/features/meals/common/models/meal_wizard_relation_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  final day = DateTime(2026, 9, 11);
  final wizard = BolusWizard(
    nightscoutObjectId: 'ns',
    remoteSource: 'https://example.com',
    createdAt: day,
    date: day,
    glucose: 120,
    units: null,
    notes: null,
    calculatorResult: null,
  );

  testWidgets(
    'unassigned entries offer linking and adding without inventing zero values',
    (tester) async {
      var linked = false;
      var added = false;
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: DayMealReviewTile(
              entry: DayMealReviewEntry(
                meal: null,
                wizards: [wizard],
                assignments: [],
              ),
              busy: false,
              onLink: (_) => linked = true,
              onCreate: (_) => added = true,
              onUnlink: (_) {},
            ),
          ),
        ),
      );
      expect(find.textContaining('11.09'), findsNothing);
      expect(find.byTooltip('Połącz z posiłkiem'), findsOneWidget);
      expect(find.textContaining('— g WW'), findsOneWidget);
      await tester.tap(find.byTooltip('Połącz z posiłkiem'));
      await tester.tap(find.byTooltip('Dodaj posiłek wstecz'));
      expect(linked, isTrue);
      expect(added, isTrue);
      await tester.tap(find.text('Wpis kalkulatora do sprawdzenia'));
      await tester.pumpAndSettle();
      expect(find.textContaining('— g WW'), findsNWidgets(2));
    },
  );

  testWidgets(
    'linked meals preserve their name and allow removing the specific assignment',
    (tester) async {
      int? removed;
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: DayMealReviewTile(
              entry: DayMealReviewEntry(
                meal: DayRecordedMeal(id: 7, name: 'Kolacja', eatenAt: day),
                wizards: [wizard],
                assignments: [
                  const MealWizardAssignment(
                    id: 9,
                    mealId: 7,
                    localId: null,
                    remoteId: 'ns',
                    remoteSource: 'https://example.com',
                    type: MealWizardRelationType.continuation,
                  ),
                ],
              ),
              busy: false,
              onLink: (_) {},
              onCreate: (_) {},
              onUnlink: (id) => removed = id,
            ),
          ),
        ),
      );
      expect(find.text('Kolacja'), findsOneWidget);
      await tester.tap(find.text('Kolacja'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Kolejna część'), findsOneWidget);
      await tester.tap(find.byTooltip('Usuń powiązanie'));
      expect(removed, 9);
    },
  );

  testWidgets('review retries failed history requests', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dayMealReviewProvider(day).overrideWith((ref) async {
            if (++calls == 1) throw StateError('offline');
            return [];
          }),
        ],
        child: localizedMaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: DayMealReviewSection(date: day)),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spróbuj ponownie'));
    await tester.pumpAndSettle();
    expect(
      find.text('Brak posiłków i wpisów kalkulatora w historii tego dnia.'),
      findsOneWidget,
    );
    expect(calls, 2);
  });

  testWidgets(
    'picker lists selected day meals and exposes continuation choice',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dayMealCandidatesProvider(day).overrideWith(
              (ref) async => [
                DayRecordedMeal(
                  id: 1,
                  name: 'Dzisiejsza kolacja',
                  eatenAt: day.add(const Duration(hours: 18)),
                ),
              ],
            ),
          ],
          child: localizedMaterialApp(
            home: Scaffold(body: DayMealLinkPicker(date: day)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Dzisiejsza kolacja'), findsOneWidget);
      await tester.tap(
        find.byType(DropdownButtonFormField<MealWizardRelationType>),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kolejna część').last);
      await tester.pumpAndSettle();
      expect(find.text('Kolejna część'), findsOneWidget);
    },
  );
}

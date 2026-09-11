import 'package:diabeatthis/core/domain/model/bolus_wizard.dart' as domain;
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/day_analysis/data/providers/day_meal_review_provider.dart';
import 'package:diabeatthis/features/day_analysis/data/repositories/day_local_history_repository.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_recorded_meal.dart';
import 'package:diabeatthis/features/day_analysis/domain/use_cases/build_day_meal_review_use_case.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_meal_link_picker.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_meal_review_section.dart';
import 'package:diabeatthis/features/meals/data/repositories/meal_wizard_link_repository.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  testWidgets(
    'selecting a meal persists the link, refreshes the group and supports undo',
    (tester) async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final day = DateTime(2026, 9, 11);
      final id = await db
          .into(db.meal)
          .insert(
            MealCompanion.insert(
              name: 'Śniadanie',
              plannedAt: day.millisecondsSinceEpoch,
              status: const Value('summarized'),
            ),
          );
      final wizard = domain.BolusWizard(
        nightscoutObjectId: 'ns',
        remoteSource: 'https://example.com',
        createdAt: day,
        date: day,
        glucose: 120,
        units: null,
        notes: null,
        calculatorResult: null,
      );
      final links = MealWizardLinkRepository(db);
      final local = DayLocalHistoryRepository(db);
      final build = BuildDayMealReviewUseCase(
        loadTreatments: (_, _) async => [wizard],
        loadAssignments: links.forWizards,
        loadMeals: (start, end, ids) =>
            local.loadRecordedMeals(start, end, includeIds: ids),
        now: () => day.add(const Duration(hours: 12)),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            dayMealReviewProvider(day).overrideWith((ref) => build(day)),
            dayMealCandidatesProvider(day).overrideWith(
              (ref) async => [
                DayRecordedMeal(id: id, name: 'Śniadanie', eatenAt: day),
              ],
            ),
          ],
          child: localizedMaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: DayMealReviewSection(date: day),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Dodaj posiłek wstecz'), findsOneWidget);
      await tester.tap(find.byTooltip('Połącz z posiłkiem'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(DayMealLinkPicker),
          matching: find.widgetWithText(ListTile, 'Śniadanie'),
        ),
      );
      await tester.pumpAndSettle();
      expect(await links.forMeal(id), hasLength(1));
      expect(find.text('Wpis kalkulatora do sprawdzenia'), findsNothing);
      expect(find.text('Śniadanie'), findsOneWidget);
      await tester.tap(find.text('Śniadanie'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Usuń powiązanie'));
      await tester.pumpAndSettle();
      expect(await links.forMeal(id), isEmpty);
      expect(find.text('Wpis kalkulatora do sprawdzenia'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' hide Treat;
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/day_analysis/data/providers/day_low_treatment_review_provider.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_low_treatment_review_section.dart';
import 'package:diabeatthis/features/low_treatment/data/repositories/low_treatment_review_repository.dart';
import 'package:diabeatthis/features/low_treatment/domain/models/recorded_low_treatment.dart';
import 'package:diabeatthis/features/low_treatment/domain/use_cases/build_low_treatment_review_use_case.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  testWidgets(
    'multiple source entries share one consumption card and undo independently',
    (tester) async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final day = DateTime(2026, 9, 10);
      final time = day.add(const Duration(hours: 12));
      final meal = await db.mealDao.createLowTreatmentEntry(
        name: 'Low',
        eatenAt: time,
      );
      final repository = LowTreatmentReviewRepository(db);
      final event = Treat(externalId: 'id', createdAt: time, carbs: 12);
      final second = Treat(
        externalId: 'second',
        createdAt: time.add(const Duration(minutes: 5)),
        carbs: 8,
      );
      await repository.save(event, mealId: meal.id);
      await repository.save(second, mealId: meal.id);
      final lows = [
        RecordedLowTreatment(mealId: meal.id, eatenAt: time, netCarbsGrams: 20),
      ];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            dayLowTreatmentReviewProvider(day).overrideWith(
              (ref) async => const BuildLowTreatmentReviewUseCase()(
                events: [event, second],
                recorded: lows,
                decisions: await repository.fetch(
                  day,
                  day.add(const Duration(days: 1)),
                ),
              ),
            ),
          ],
          child: localizedMaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: DayLowTreatmentReviewSection(date: day),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('12:00 · Dosłodzenie · 20 g'), findsOneWidget);
      expect(find.text('2 powiązane wpisy'), findsOneWidget);
      expect(find.text('1 do sprawdzenia'), findsNothing);
      await tester.tap(find.byTooltip('Cofnij powiązanie wpisu').first);
      await tester.pumpAndSettle();
      final decisions = await repository.fetch(
        day,
        day.add(const Duration(days: 1)),
      );
      expect(decisions, hasLength(1));
      expect(decisions.single.occurredAt, second.createdAt);
      expect(decisions.single.mealId, meal.id);
      expect(find.text('1 do sprawdzenia'), findsOneWidget);
      expect(find.text('2 powiązane wpisy'), findsNothing);
      expect(find.textContaining('Dosłodzenie · 20 g'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

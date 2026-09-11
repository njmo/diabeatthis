import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' hide Treat;
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/day_analysis/data/providers/day_low_treatment_review_provider.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_low_treatment_review_section.dart';
import 'package:diabeatthis/features/low_treatment/data/repositories/low_treatment_review_repository.dart';
import 'package:diabeatthis/features/low_treatment/domain/models/low_treatment_review_entry.dart';
import 'package:diabeatthis/features/low_treatment/domain/models/low_treatment_review_list.dart';
import 'package:diabeatthis/features/low_treatment/domain/models/recorded_low_treatment.dart';
import 'package:diabeatthis/features/low_treatment/domain/use_cases/build_low_treatment_review_use_case.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  final day = DateTime(2026, 9, 10);
  final time = day.add(const Duration(hours: 12));
  final event = Treat(externalId: 'current', createdAt: time, carbs: 12);

  testWidgets(
    'stale decision can be reset and linked to current source identity',
    (tester) async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = LowTreatmentReviewRepository(db);
      final meal = await db.mealDao.createLowTreatmentEntry(
        name: 'Low',
        eatenAt: time,
      );
      await repo.save(event.copyWith(externalId: 'previous'), mealId: meal.id);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            dayLowTreatmentReviewProvider(day).overrideWith(
              (ref) async => const BuildLowTreatmentReviewUseCase()(
                events: [event],
                recorded: [
                  RecordedLowTreatment(
                    mealId: meal.id,
                    eatenAt: time,
                    netCarbsGrams: 12,
                  ),
                ],
                decisions: await repo.fetch(
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
      expect(find.text('Połącz'), findsNothing);
      await tester.tap(find.byTooltip('Cofnij decyzję'));
      await tester.pumpAndSettle();
      expect(await repo.fetch(time, time), isEmpty);
      await tester.tap(find.text('Połącz'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('12:00 · 12 g'));
      await tester.pumpAndSettle();
      final saved = (await repo.fetch(time, time)).single;
      expect(saved.externalId, 'current');
      expect(saved.mealId, meal.id);
      expect(find.text('1 do sprawdzenia'), findsNothing);
    },
  );

  test('source ambiguity without stale decision remains protected', () {
    final entries = const BuildLowTreatmentReviewUseCase()(
      events: [event, event.copyWith(carbs: 20)],
      recorded: [],
      decisions: [],
    );
    expect(entries.single.ambiguous, isTrue);
    expect(entries.single.staleDecision, isFalse);
    expect(entries.single.canReset, isFalse);
    expect(entries.single.isPending, isTrue);
  });

  test(
    'grouping keeps consumption once, links reversible and pending count consistent',
    () {
      final recorded = RecordedLowTreatment(
        mealId: 7,
        eatenAt: time,
        netCarbsGrams: 20,
      );
      final entries = [
        LowTreatmentReviewEntry(event: event, recorded: recorded),
        LowTreatmentReviewEntry(
          event: event.copyWith(
            createdAt: time.add(const Duration(minutes: 5)),
          ),
          recorded: recorded,
        ),
        LowTreatmentReviewEntry(event: event.copyWith(externalId: 'pending')),
        LowTreatmentReviewEntry(
          event: event.copyWith(externalId: 'dismissed'),
          dismissed: true,
        ),
      ];
      final list = LowTreatmentReviewList(entries);
      expect(list.visible, hasLength(2));
      expect(list.recorded, [recorded]);
      expect(list.linkedEvents[7], hasLength(2));
      expect(list.pendingCount, 1);
      expect(list.dismissed, hasLength(1));
      expect(() => list.linkedEvents[7]!.clear(), throwsUnsupportedError);
      expect(LowTreatmentReviewList(entries).visible, list.visible);
    },
  );
}

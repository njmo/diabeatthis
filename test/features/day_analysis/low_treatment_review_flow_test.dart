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
  testWidgets('inline review links, undoes and remembers dismissal', (
    tester,
  ) async {
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
    final lows = [
      RecordedLowTreatment(mealId: meal.id, eatenAt: time, netCarbsGrams: 12),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          dayLowTreatmentReviewProvider(day).overrideWith(
            (ref) async => const BuildLowTreatmentReviewUseCase()(
              events: [event],
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
    expect(find.text('1 do sprawdzenia'), findsOneWidget);
    await tester.tap(find.text('Połącz'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('12:00 · 12 g'));
    await tester.pumpAndSettle();
    expect((await repository.fetch(time, time)).single.mealId, meal.id);
    expect(find.text('1 do sprawdzenia'), findsNothing);
    await tester.tap(find.byTooltip('Cofnij decyzję'));
    await tester.pumpAndSettle();
    expect(await repository.fetch(time, time), isEmpty);
    await tester.tap(find.text('To nie dosłodzenie'));
    await tester.pumpAndSettle();
    expect((await repository.fetch(time, time)).single.dismissed, isTrue);
    expect(find.text('1 do sprawdzenia'), findsNothing);
    await tester.tap(find.text('Oznaczone jako inne wpisy'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Cofnij decyzję'));
    await tester.pumpAndSettle();
    expect(find.text('1 do sprawdzenia'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

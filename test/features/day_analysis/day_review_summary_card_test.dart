import 'dart:async';

import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:diabeatthis/features/day_analysis/data/providers/day_low_treatment_review_provider.dart';
import 'package:diabeatthis/features/day_analysis/data/providers/day_meal_review_provider.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_meal_review_entry.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_review_section.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_review_summary_card.dart';
import 'package:diabeatthis/features/low_treatment/domain/models/low_treatment_review_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  final date = DateTime(2026, 9, 11);

  testWidgets(
    'counts unresolved entries, excludes dismissals and opens lists',
    (tester) async {
      var mealsOpened = false;
      var lowsOpened = false;
      final event = Treat(externalId: 'source', createdAt: date, carbs: 10);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dayMealReviewProvider(date).overrideWith(
              (ref) async => [
                DayMealReviewEntry(meal: null, wizards: [], assignments: []),
              ],
            ),
            dayLowTreatmentReviewProvider(date).overrideWith(
              (ref) async => [
                LowTreatmentReviewEntry(event: event),
                LowTreatmentReviewEntry(event: event, dismissed: true),
              ],
            ),
          ],
          child: localizedMaterialApp(
            home: Scaffold(
              body: DayReviewSummaryCard(
                date: date,
                onMeals: () => mealsOpened = true,
                onLowTreatments: () => lowsOpened = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1 do sprawdzenia'), findsNWidgets(2));
      expect(find.text('Wszystkie wpisy sprawdzone'), findsNothing);
      await tester.tap(find.text('Posiłki'));
      await tester.tap(find.text('Dosłodzenia'));
      expect(mealsOpened, isTrue);
      expect(lowsOpened, isTrue);
    },
  );

  testWidgets('unknown history is never reported as complete', (tester) async {
    final pending = Completer<List<LowTreatmentReviewEntry>>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dayMealReviewProvider(date).overrideWith((ref) async => []),
          dayLowTreatmentReviewProvider(
            date,
          ).overrideWith((ref) => pending.future),
        ],
        child: localizedMaterialApp(
          home: Scaffold(
            body: DayReviewSummaryCard(
              date: date,
              onMeals: () {},
              onLowTreatments: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Sprawdzanie wpisów…'), findsOneWidget);
    expect(find.text('Wszystkie wpisy sprawdzone'), findsNothing);
    pending.completeError(StateError('History unavailable'));
    await tester.pumpAndSettle();
    expect(find.text('Brak danych — sprawdź listę'), findsOneWidget);
    expect(find.text('Wszystkie wpisy sprawdzone'), findsNothing);
  });

  testWidgets('complete status requires both loaded lists', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dayMealReviewProvider(date).overrideWith((ref) async => []),
          dayLowTreatmentReviewProvider(date).overrideWith((ref) async => []),
        ],
        child: localizedMaterialApp(
          home: Scaffold(
            body: DayReviewSummaryCard(
              date: date,
              onMeals: () {},
              onLowTreatments: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Wszystkie wpisy sprawdzone'), findsOneWidget);
  });
  testWidgets('summary scrolls to a section outside the viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(400, 300));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          dayMealReviewProvider(date).overrideWith((ref) async => []),
          dayLowTreatmentReviewProvider(date).overrideWith((ref) async => []),
        ],
        child: localizedMaterialApp(
          home: Scaffold(
            body: ListView(
              children: [
                DayReviewSection(date: date),
                const SizedBox(height: 400),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final target = find.text('Dosłodzenia do sprawdzenia');
    expect(tester.getTopLeft(target).dy, greaterThan(300));
    await tester.tap(find.text('Dosłodzenia'));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(target).dy, inInclusiveRange(0, 100));
    expect(tester.takeException(), isNull);
  });
}

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:diabeatthis/features/day_analysis/data/providers/day_context_provider.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_context.dart';
import 'package:diabeatthis/features/day_analysis/domain/use_cases/build_day_context_use_case.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/today_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';
import 'build_day_context_use_case_test.dart' show emptyMeals;

void main() {
  testWidgets(
    'date navigation isolates pending results and refreshes selected date',
    (tester) async {
      final now = DateTime(2026, 9, 11, 12);
      final previous = DateTime(2026, 9, 10);
      final older = DateTime(2026, 9, 9);
      final builder = BuildDayContextUseCase(
        now: () => now,
        loadGlucose: (_, _) async => [],
        loadTreatments: (_, _) async => [],
        loadMeals: (_, _) async => emptyMeals,
        loadLowTreatments: (_, _) async => [],
        loadActivities: (_, _) async => [],
      );
      final pending = Completer<DayContext>();
      var olderCalls = 0;
      await withClock(Clock.fixed(now), () async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              dayContextProvider.overrideWith((ref) => builder()),
              dayContextForDateProvider(
                previous,
              ).overrideWith((ref) => pending.future),
              dayContextForDateProvider(older).overrideWith((ref) {
                olderCalls++;
                return builder(date: older);
              }),
            ],
            child: localizedMaterialApp(
              home: const Scaffold(body: TodayPage()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Dzisiaj · wersja robocza'), findsOneWidget);
        expect(
          tester
              .widget<IconButton>(
                find.byWidgetPredicate(
                  (widget) =>
                      widget is IconButton &&
                      widget.tooltip == 'Następny dzień',
                ),
              )
              .onPressed,
          isNull,
        );
        await tester.tap(find.byTooltip('Poprzedni dzień'));
        await tester.pump();
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await tester.tap(find.byTooltip('Poprzedni dzień'));
        await tester.pumpAndSettle();
        expect(find.text('09.09.2026'), findsOneWidget);
        expect(find.text('Dane do 10.09.2026 00:00'), findsOneWidget);
        expect(find.text('Dzień · wersja robocza'), findsOneWidget);
        pending.complete(await builder(date: previous));
        await tester.pumpAndSettle();
        expect(find.text('Dane do 10.09.2026 00:00'), findsOneWidget);
        await tester.tap(find.byTooltip('Odśwież'));
        await tester.pumpAndSettle();
        expect(olderCalls, 2);
        await tester.tap(find.byTooltip('Wróć do dzisiaj'));
        await tester.pumpAndSettle();
        expect(find.text('Dzisiaj · wersja robocza'), findsOneWidget);
        expect(find.text('11.09.2026'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    },
  );
}

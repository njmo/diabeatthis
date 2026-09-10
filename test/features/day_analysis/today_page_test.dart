import 'dart:async';
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
    'refresh replaces the draft and renders source failures explicitly',
    (tester) async {
      final pending = Completer<DayContext>();
      var calls = 0;
      final day = await BuildDayContextUseCase(
        now: () => DateTime(2026, 9, 10, 12),
        loadGlucose: (_, _) async => throw StateError('offline'),
        loadTreatments: (_, _) async => [],
        loadMeals: (_, _) async => emptyMeals,
        loadLowTreatments: (_, _) async => [],
        loadActivities: (_, _) async => [],
      )();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            dayContextProvider.overrideWith((ref) {
              calls++;
              return calls == 1 ? Future.value(day) : pending.future;
            }),
          ],
          child: localizedMaterialApp(home: const Scaffold(body: TodayPage())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Dzisiaj · wersja robocza'), findsOneWidget);
      expect(
        find.text(
          'Część źródeł jest niedostępna. Pozostałe wyniki pokazano poniżej.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Odśwież'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      pending.complete(day);
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(tester.takeException(), isNull);
    },
  );
}

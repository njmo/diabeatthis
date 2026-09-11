import 'package:diabeatthis/features/day_analysis/data/providers/day_context_provider.dart';
import 'package:diabeatthis/features/day_analysis/data/providers/day_summary_provider.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/accepted_day_summary.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_summary_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';
import 'accept_day_summary_test.dart' show preview;

void main() {
  testWidgets('accepted document is rendered without requesting live draft', (
    tester,
  ) async {
    final date = DateTime(2026, 9, 10);
    var draftLoads = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          acceptedDaySummaryProvider(date).overrideWith(
            (ref) async => AcceptedDaySummary(
              acceptedAt: DateTime(2026, 9, 11, 8),
              snapshot: preview(),
            ),
          ),
          daySummaryDraftProvider(date).overrideWith((ref) async {
            draftLoads++;
            throw StateError('Live history must not be fetched');
          }),
        ],
        child: localizedMaterialApp(
          home: Scaffold(body: DaySummarySheet(date: date)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Zatwierdzono 11.09.2026 08:00'), findsOneWidget);
    expect(find.text('Zatwierdź podsumowanie'), findsNothing);
    expect(draftLoads, 0);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'retry invalidates failed day history instead of reusing its cached error',
    (tester) async {
      final date = DateTime(2026, 9, 10);
      var contextLoads = 0;
      var recovered = false;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            acceptedDaySummaryProvider(date).overrideWith((ref) async => null),
            dayContextForDateProvider(date).overrideWith((ref) async {
              contextLoads++;
              throw StateError('Source error');
            }),
            daySummaryDraftProvider(date).overrideWith((ref) async {
              if (recovered) return preview();
              await ref.watch(dayContextForDateProvider(date).future);
              return preview();
            }),
          ],
          child: localizedMaterialApp(
            home: Scaffold(body: DaySummarySheet(date: date)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(contextLoads, 1);
      final retry = find.text(
        'Nie udało się przygotować podsumowania. Spróbuj ponownie',
      );
      expect(retry, findsOneWidget);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(contextLoads, 2);
      recovered = true;
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(find.text('Zatwierdź podsumowanie'), findsOneWidget);
    },
  );
}

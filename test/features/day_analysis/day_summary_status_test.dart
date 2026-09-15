import 'package:clock/clock.dart';
import 'package:diabeatthis/features/day_analysis/data/providers/day_summary_provider.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_summary_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';
import 'day_dml_test.dart' show dmlFixture;

void main() {
  final date = DateTime(2026, 10, 25);

  testWidgets(
    'accepted summary replaces the action after archive invalidation',
    (tester) async {
      var accepted = false;
      final container = ProviderContainer(
        overrides: [
          acceptedDaySummaryProvider(
            date,
          ).overrideWith((ref) async => accepted ? dmlFixture() : null),
        ],
      );
      addTearDown(container.dispose);
      await withClock(Clock.fixed(DateTime(2026, 10, 26, 9)), () async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: localizedMaterialApp(
              home: Scaffold(body: DaySummaryStatus(date: date)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Niepodsumowany · podsumuj dzień'), findsOneWidget);
        accepted = true;
        container.invalidate(acceptedDaySummaryProvider(date));
        await tester.pumpAndSettle();
        expect(find.text('Niepodsumowany · podsumuj dzień'), findsNothing);
        expect(find.text('Podsumowany · zobacz podsumowanie'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
      });
    },
  );

  testWidgets('current day explains when summarizing is available', (
    tester,
  ) async {
    await withClock(Clock.fixed(DateTime(2026, 10, 25, 22)), () async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            acceptedDaySummaryProvider(date).overrideWith((ref) async => null),
          ],
          child: localizedMaterialApp(
            home: Scaffold(body: DaySummaryStatus(date: date)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Dzień trwa · podsumowanie dostępne jutro'),
        findsOneWidget,
      );
      expect(find.byType(FilledButton), findsNothing);
    });
  });
}

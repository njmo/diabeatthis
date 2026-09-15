import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_summary_snapshot.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_review_status_tile.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_summary_review_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'archived facts follow the selected language without changing stored data',
    (tester) async {
      final snapshot = DaySummarySnapshot(
        dayKey: '2026-09-10',
        asOf: DateTime.utc(2026, 9, 11),
        builtAt: DateTime.utc(2026, 9, 11, 8),
        utcOffsetMinutes: 120,
        metrics: {DaySummaryMetric.glucoseMean: 123.5},
        limitations: ['glucose'],
        review: [],
      );
      final payload = snapshot.encode();
      Future<void> show(String language) async {
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(language),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: DaySummaryReviewForm(snapshot: snapshot),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await show('en');
      expect(find.text('Mean · mg/dL'), findsOneWidget);
      expect(find.text('123.5'), findsOneWidget);
      expect(find.text('Incomplete data: glucose.'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ExpansionTile),
          matching: find.text('Detailed statistics'),
        ),
        findsNWidgets(2),
      );
      await show('pl');
      expect(find.text('Średnia · mg/dl'), findsOneWidget);
      expect(find.text('123,5'), findsOneWidget);
      expect(find.text('Niepełne dane: glikemia.'), findsOneWidget);
      expect(snapshot.encode(), payload);
    },
  );

  testWidgets('review counter and retry state are translated into English', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Column(
            children: [
              DayReviewStatusTile(
                title: 'Meals',
                pending: const AsyncData(2),
                onTap: () {},
              ),
              DayReviewStatusTile(
                title: 'Low treatments',
                pending: AsyncError(StateError('offline'), StackTrace.empty),
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('2 to review'), findsOneWidget);
    expect(find.text('No data — check the list'), findsOneWidget);
    expect(find.textContaining('do sprawdzenia'), findsNothing);
  });
}

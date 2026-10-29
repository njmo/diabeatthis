import 'package:clock/clock.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/features/activity/data/drafts/activity_draft.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/dashboard_activity_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> open(
    WidgetTester tester, {
    required ActivityEntryMode mode,
    required ValueChanged<DashboardActivityAction?> save,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                child: const Text('Open'),
                onPressed: () async {
                  save(
                    await showModalBottomSheet<DashboardActivityAction>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => DashboardActivitySheet(
                        initialActivity: const ActivityDraft.existing(
                          id: 1,
                          name: 'Walk',
                          percentagePre: 0,
                          percentagePost: 0,
                          durationMinutes: null,
                        ),
                        initialMode: mode,
                        initialStart: DateTime(
                          2026,
                          10,
                          29,
                          mode == ActivityEntryMode.planned ? 18 : 10,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'planning an activity with a manual end accepts an empty duration',
    (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 10, 29, 12)), () async {
        DashboardActivityAction? result;
        await open(
          tester,
          mode: ActivityEntryMode.planned,
          save: (action) => result = action,
        );
        expect(
          find.text('Leave empty to end the activity manually.'),
          findsOneWidget,
        );
        await tester.tap(find.text('Add session'));
        await tester.pumpAndSettle();
        expect(result, isNotNull);
        expect(result!.isScheduled, isTrue);
        expect(result!.durationMinutes, isNull);
        expect(result!.startedAt, DateTime(2026, 10, 29, 18));
      });
    },
  );

  testWidgets('a nonempty invalid duration still prevents planning', (
    tester,
  ) async {
    await withClock(Clock.fixed(DateTime(2026, 10, 29, 12)), () async {
      DashboardActivityAction? result;
      await open(
        tester,
        mode: ActivityEntryMode.planned,
        save: (action) => result = action,
      );
      await tester.enterText(find.byType(TextFormField), '0');
      await tester.tap(find.text('Add session'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(find.byType(DashboardActivitySheet), findsOneWidget);
    });
  });

  testWidgets('completed historical activities still require a duration', (
    tester,
  ) async {
    await withClock(Clock.fixed(DateTime(2026, 10, 29, 12)), () async {
      DashboardActivityAction? result;
      await open(
        tester,
        mode: ActivityEntryMode.historical,
        save: (action) => result = action,
      );
      await tester.tap(find.text('Save completed activity'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      expect(find.byType(DashboardActivitySheet), findsOneWidget);
    });
  });
}

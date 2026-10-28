import 'package:clock/clock.dart';
import 'package:diabeatthis/common/l10n/generated/app_localizations.dart';
import 'package:diabeatthis/features/activity/data/drafts/activity_draft.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/dashboard_activity_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> showForm(
    WidgetTester tester,
    int? duration, {
    ValueChanged<DashboardActivityAction?>? onSaved,
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
                  final action =
                      await showModalBottomSheet<DashboardActivityAction>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => DashboardActivitySheet(
                          initialActivity: ActivityDraft.existing(
                            id: 1,
                            name: 'PE',
                            percentagePre: 0,
                            percentagePost: 0,
                            durationMinutes: duration,
                          ),
                          initialMode: ActivityEntryMode.historical,
                          initialStart: DateTime(2026, 10, 27, 17),
                        ),
                      );
                  onSaved?.call(action);
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

  testWidgets('uses activity duration and derives the historical end', (
    tester,
  ) async {
    DashboardActivityAction? result;
    await withClock(Clock.fixed(DateTime(2026, 10, 28, 12)), () async {
      await showForm(tester, 45, onSaved: (action) => result = action);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        '45',
      );
      await tester.tap(find.text('Save completed activity'));
      await tester.pumpAndSettle();
      expect(result?.startedAt, DateTime(2026, 10, 27, 17));
      expect(result?.endedAt, DateTime(2026, 10, 27, 17, 45));
    });
  });

  testWidgets('without an activity duration the required field stays empty', (
    tester,
  ) async {
    await withClock(Clock.fixed(DateTime(2026, 10, 28, 12)), () async {
      await showForm(tester, null);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        isEmpty,
      );
      await tester.tap(find.text('Save completed activity'));
      await tester.pumpAndSettle();
      expect(find.byType(DashboardActivitySheet), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField))
            .controller!
            .text,
        isEmpty,
      );
      expect(tester.takeException(), isNull);
    });
  });
}

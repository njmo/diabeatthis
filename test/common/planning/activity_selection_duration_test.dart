import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/features/activity/data/drafts/activity_draft.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/dashboard_activity_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final customEditor in [true, false]) {
    testWidgets(
      'choosing a different existing activity resets manual duration even with equal defaults: editor=$customEditor',
      (tester) async {
        const next = ActivityDraft.existing(
          id: 2,
          name: 'Run',
          percentagePre: 20,
          percentagePost: 30,
          durationMinutes: 30,
        );
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: DashboardActivitySheet(
                  initialActivity: const ActivityDraft.existing(
                    id: 1,
                    name: 'Walk',
                    percentagePre: 20,
                    percentagePost: 30,
                    durationMinutes: 30,
                  ),
                  initialMode: ActivityEntryMode.planned,
                  initialDuration: 45,
                  picker: (_) async => next,
                  activityEditor: customEditor ? (_, _) async => next : null,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final language = AppLocalizations.of(
          tester.element(find.byType(DashboardActivitySheet)),
        );
        await tester.tap(
          find.byTooltip(language.dashboardChangeActivityTooltip),
        );
        await tester.pumpAndSettle();
        expect(find.text('Run'), findsOneWidget);
        expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField))
              .controller
              ?.text,
          '30',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}

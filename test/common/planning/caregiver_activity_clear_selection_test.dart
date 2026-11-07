import 'package:diabeatthis/common/family_sync/presentation/family_activity_plan_form.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/activity/data/drafts/activity_draft.dart';
import 'package:diabeatthis/features/activity/presentation/widgets/activity_picker_sheet.dart';
import 'package:diabeatthis/features/activity/presentation/widgets/selected_activity_card.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/dashboard_activity_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final locked in [false, true]) {
    testWidgets(
      'clear activity selection respects move lock=$locked without any writes',
      (tester) async {
        var submitted = false;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWith(
                (_) => throw StateError('No local writes'),
              ),
            ],
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: FamilyActivityPlanForm(
                  rows: const [],
                  moveOnly: locked,
                  initial: const {
                    'activityId': null,
                    'activity': {
                      'name': 'New walk',
                      'percentagePre': 20,
                      'percentagePost': 30,
                      'durationMinutes': 30,
                    },
                  },
                  onSubmit: (_) async {
                    submitted = true;
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final language = AppLocalizations.of(
          tester.element(find.byType(FamilyActivityPlanForm)),
        );
        expect(find.byType(SelectedActivityCard), findsOneWidget);
        final clear = find.byTooltip(language.activityClearSelection);
        if (locked) {
          expect(clear, findsNothing);
          return;
        }
        await tester.tap(clear);
        await tester.pumpAndSettle();
        expect(find.byType(SelectedActivityCard), findsNothing);
        expect(find.text(language.activityPickTitle), findsOneWidget);
        expect(submitted, isFalse);
        await tester.tap(find.text(language.activityPickTitle));
        await tester.pumpAndSettle();
        expect(find.byType(ActivityPickerSheet), findsOneWidget);
        expect(find.text(language.activityCreateTitle), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
  for (final draft in [true, false]) {
    testWidgets(
      'clear capability leaves patient defaults and existing records unchanged: draft=$draft',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: DashboardActivitySheet(
                  initialActivity: draft
                      ? const ActivityDraft.draft(
                          name: 'Draft',
                          percentagePre: 20,
                          percentagePost: 30,
                          durationMinutes: 30,
                        )
                      : const ActivityDraft.existing(
                          id: 1,
                          name: 'Saved',
                          percentagePre: 20,
                          percentagePost: 30,
                          durationMinutes: 30,
                        ),
                  allowClearDraftSelection: !draft,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final language = AppLocalizations.of(
          tester.element(find.byType(DashboardActivitySheet)),
        );
        expect(find.byTooltip(language.activityClearSelection), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

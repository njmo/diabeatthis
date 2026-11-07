import 'package:diabeatthis/common/family_sync/presentation/family_activity_plan_form.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/activity/presentation/widgets/activity_definition_sheet.dart';
import 'package:diabeatthis/features/activity/presentation/widgets/activity_schedule_setup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'empty caregiver catalog can create an inline definition without patient DB',
    (tester) async {
      String? operation;
      Map<String, dynamic>? sent;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWith(
              (_) => throw StateError('No patient DB'),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: FamilyActivityPlanForm(
                rows: const [],
                onSubmit: (_) async => throw StateError('Expected operation'),
                onActivitySubmit: (type, values) async {
                  operation = type;
                  sent = values;
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
      await tester.tap(find.text(language.activityPickTitle));
      await tester.pumpAndSettle();
      await tester.tap(find.text(language.activityCreateTitle));
      await tester.pumpAndSettle();
      expect(find.byType(ActivityDefinitionSheet), findsOneWidget);
      expect(find.byType(ActivityScheduleSetup), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('activity-name-field')),
        'Walking',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('activity-percentage-pre-field')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('activity-percentage-pre-field')),
        '20',
      );
      await tester.enterText(
        find.byKey(const ValueKey('activity-percentage-post-field')),
        '30',
      );
      await tester.ensureVisible(
        find.ancestor(
          of: find.text(language.activityHasPlannedDurationTitle),
          matching: find.byType(CheckboxListTile),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text(language.activityHasPlannedDurationTitle));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('activity-duration-field')),
        '1441',
      );
      await tester.tap(find.text(language.commonCreate));
      await tester.pumpAndSettle();
      expect(find.byType(ActivityDefinitionSheet), findsOneWidget);
      expect(find.text(language.planningDurationTooLong(1440)), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('activity-duration-field')),
        '30',
      );
      await tester.tap(find.text(language.commonCreate));
      await tester.pumpAndSettle();
      expect(find.byType(ActivityDefinitionSheet), findsNothing);
      expect(find.text('Walking'), findsOneWidget);
      await tester.tap(find.text(language.activityEntryNow));
      await tester.pumpAndSettle();
      await tester.tap(find.text(language.activityStartNow));
      await tester.pumpAndSettle();
      expect(operation, 'startActivity');
      expect(sent!['activityId'], isNull);
      expect(sent!['activity'], {
        'name': 'Walking',
        'percentagePre': 20,
        'percentagePost': 30,
        'durationMinutes': 30,
      });
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('retry keeps the inline name sensitivity and duration', (
    tester,
  ) async {
    Map<String, dynamic>? sent;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWith((_) => throw StateError('No local DB')),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: FamilyActivityPlanForm(
              rows: const [],
              operation: 'startActivity',
              initial: const {
                'activityId': null,
                'activity': {
                  'name': 'Retry walk',
                  'percentagePre': 20,
                  'percentagePost': 30,
                  'durationMinutes': 45,
                },
              },
              onSubmit: (_) async {},
              onActivitySubmit: (type, values) async {
                sent = values;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry walk'), findsOneWidget);
    final language = AppLocalizations.of(
      tester.element(find.byType(FamilyActivityPlanForm)),
    );
    await tester.tap(find.text(language.activityStartNow));
    await tester.pumpAndSettle();
    expect(sent!['activity'], {
      'name': 'Retry walk',
      'percentagePre': 20,
      'percentagePost': 30,
      'durationMinutes': 45,
    });
    expect(tester.takeException(), isNull);
  });
}

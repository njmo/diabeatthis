import 'package:clock/clock.dart';
import 'package:diabeatthis/common/l10n/generated/app_localizations.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/activity/data/drafts/activity_draft.dart';
import 'package:diabeatthis/features/activity/presentation/widgets/activity_definition_sheet.dart';
import 'package:diabeatthis/features/activity/presentation/widgets/activity_upcoming_button.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/dashboard_activity_sheet.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget app(DatabaseImpl db, Widget child) => ProviderScope(
  overrides: [databaseProvider.overrideWithValue(db)],
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  ),
);

void main() {
  late DatabaseImpl db;
  setUp(() => db = DatabaseImpl(NativeDatabase.memory()));
  tearDown(() => db.close());

  testWidgets('dashboard adds a one-off session with no recurring controls', (
    tester,
  ) async {
    await withClock(Clock.fixed(DateTime(2026, 10, 28, 12)), () async {
      DashboardActivityAction? result;
      await tester.pumpWidget(
        app(
          db,
          Builder(
            builder: (context) => TextButton(
              child: const Text('Open'),
              onPressed: () async {
                result = await showModalBottomSheet<DashboardActivityAction>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => DashboardActivitySheet(
                    initialActivity: const ActivityDraft.existing(
                      id: 1,
                      name: 'Jujitsu',
                      percentagePre: 10,
                      percentagePost: 20,
                      durationMinutes: 60,
                    ),
                    initialMode: ActivityEntryMode.planned,
                    initialStart: DateTime(2026, 10, 28, 17),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('Repeat weekly'), findsNothing);
      expect(find.text('Session planning'), findsNothing);
      expect(find.text('Add session'), findsOneWidget);
      await tester.tap(find.text('Add session'));
      await tester.pumpAndSettle();
      expect(result?.isScheduled, isTrue);
      expect(result?.startedAt, DateTime(2026, 10, 28, 17));
      expect(await db.select(db.activitySchedule).get(), isEmpty);
    });
  });

  testWidgets('activity history opens upcoming sessions from its button', (
    tester,
  ) async {
    await tester.pumpWidget(app(db, const ActivityUpcomingButton()));
    await tester.pumpAndSettle();
    expect(find.text('Upcoming activities'), findsOneWidget);
    expect(find.byIcon(Icons.calendar_month), findsNothing);
    await tester.tap(find.text('Upcoming activities'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No upcoming sessions.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'creating an activity with a cycle only creates pending occurrences',
    (tester) async {
      await withClock(Clock.fixed(DateTime(2026, 10, 28, 12)), () async {
        await tester.pumpWidget(
          app(
            db,
            Builder(
              builder: (context) => TextButton(
                child: const Text('Open'),
                onPressed: () => showActivityDefinitionSheet(context),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        for (final field in {
          'activity-name-field': 'Jujitsu',
          'activity-percentage-pre-field': '10',
          'activity-percentage-post-field': '20',
        }.entries) {
          await tester.ensureVisible(find.byKey(ValueKey(field.key)));
          await tester.enterText(find.byKey(ValueKey(field.key)), field.value);
        }
        tester.testTextInput.hide();
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Repeat weekly'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Repeat weekly'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Wed'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Wed'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Create'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(await db.select(db.activity).get(), hasLength(1));
        expect(await db.select(db.activitySchedule).get(), hasLength(1));
        final occurrences = await db.select(db.activityOccurrence).get();
        expect(occurrences, isNotEmpty);
        expect(occurrences.every((row) => row.status == 'pending'), isTrue);
        expect(await db.select(db.activityLog).get(), isEmpty);
      });
    },
  );
}

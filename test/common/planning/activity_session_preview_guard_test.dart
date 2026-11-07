import 'package:clock/clock.dart';
import 'package:diabeatthis/common/activity/insert_activity_session.dart';
import 'package:diabeatthis/common/auth/google_account.dart';
import 'package:diabeatthis/common/auth/google_authentication_providers.dart';
import 'package:diabeatthis/common/family_sync/presentation/family_record_page.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/presentation/details/nightscout_record_history.dart';
import 'package:diabeatthis/common/widgets/delete_confirmation_dialog.dart';
import 'package:diabeatthis/core/data_sources/nightscout/providers/nightscout_repository_provider.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/activity/data/models/activity_log_summary_data.dart';
import 'package:diabeatthis/features/activity/presentation/utils/delete_activity_history_entry.dart';
import 'package:diabeatthis/features/activity/presentation/widgets/activity_log_body.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';
import '../presentation/caregiver_audit_fixture.dart';
import '../presentation/family_collection_fixtures.dart';

void main() {
  final now = DateTime(2026, 11, 7, 12);
  for (final phase in ['planned', 'preparing', 'active', 'waitingForFinish']) {
    test(
      'immediate start respects persisted $phase and keeps future reservation',
      () => withClock(Clock.fixed(now), () async {
        final db = DatabaseImpl(NativeDatabase.memory());
        addTearDown(db.close);
        await db.customStatement(
          "INSERT INTO activity(name,percentage_pre,percentage_post) VALUES('Training',20,30)",
        );
        await db.customStatement(
          'INSERT INTO activity_log(activity_id,started_at) VALUES(1,?)',
          [now.add(const Duration(days: 4)).millisecondsSinceEpoch],
        );
        await db.customStatement(
          "INSERT INTO family_workflow_lock(kind,entity_id,phase,active,updated_at) VALUES('activity',1,?,1,?)",
          [phase, now.millisecondsSinceEpoch],
        );
        final write = db.transaction(
          () => insertActivitySession(db, activityId: 1, start: now),
        );
        if (phase == 'planned') {
          final log = await write;
          expect(log.id, 2);
          expect((await db.activityDao.getActiveActivityLogOrNull())?.id, 2);
          expect(await db.select(db.activityLog).get(), hasLength(2));
        } else {
          await expectLater(write, throwsStateError);
          expect(await db.select(db.activityLog).get(), hasLength(1));
        }
      }),
    );
  }
  testWidgets(
    'caregiver future log opens planned details without analysis or patient database',
    (tester) async {
      final f = CaregiverAuditFixture();
      addTearDown(f.close);
      final start = DateTime.now()
          .add(const Duration(days: 4))
          .millisecondsSinceEpoch;
      f.family.rows['activityLogs/7'] = mirrorRow('activityLogs', 7, {
        'activity_id': 5,
        'started_at': start,
        'ended_at': null,
        'created_at': start,
        'updated_at': start,
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            googleAccountProvider.overrideWith(
              (_) => Stream.value(
                const GoogleAccount(
                  uid: 'parent',
                  email: 'p@example.test',
                  displayName: 'Parent',
                ),
              ),
            ),
            databaseProvider.overrideWith(
              (_) => throw StateError('No patient database'),
            ),
            nightscoutRepositoryProvider.overrideWith(
              (_) => throw StateError('No analysis for future log'),
            ),
          ],
          child: localizedMaterialApp(
            home: FamilyRecordPage(
              family: f.family,
              kind: 'activityLogs',
              id: 7,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final language = AppLocalizations.of(
        tester.element(find.byType(FamilyRecordPage)),
      );
      expect(find.byType(ActivityLogBody), findsOneWidget);
      expect(find.byType(NightscoutRecordHistory), findsNothing);
      expect(find.text(language.activitySchedulePlanned), findsWidgets);
      expect(find.text(language.activityActive), findsNothing);
      expect(find.text(language.activityInProgress), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  for (final active in [false, true]) {
    testWidgets(
      'delete warning treats only started session as active: $active',
      (tester) async {
        final now = DateTime.now();
        final entry = ActivityLogSummaryData(
          id: 1,
          activityName: 'Training',
          activityId: 5,
          startedAt: now.add(Duration(days: active ? -1 : 1)),
          endedAt: null,
          durationMinutes: 43,
        );
        await tester.pumpWidget(
          ProviderScope(
            child: localizedMaterialApp(
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) => TextButton(
                    onPressed: () =>
                        deleteActivityHistoryEntry(context, ref, entry),
                    child: const Text('Delete'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Delete'));
        await tester.pumpAndSettle();
        final dialog = tester.widget<DeleteConfirmationDialog>(
          find.byType(DeleteConfirmationDialog),
        );
        final language = AppLocalizations.of(
          tester.element(find.byType(DeleteConfirmationDialog)),
        );
        expect(
          dialog.message.contains(language.activityHistoryDeleteActiveMessage),
          active,
        );
        await tester.tap(find.text(language.commonCancel));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  testWidgets('delete rechecks activity start before accepting confirmation', (
    tester,
  ) async {
    var now = DateTime(2026, 11, 7, 12);
    final start = now.add(const Duration(minutes: 1));
    await withClock(Clock(() => now), () async {
      final entry = ActivityLogSummaryData(
        id: 1,
        activityName: 'Training',
        activityId: 5,
        startedAt: start,
        endedAt: null,
        durationMinutes: 43,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWith(
              (_) => throw StateError('No writes before active confirmation'),
            ),
          ],
          child: localizedMaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => TextButton(
                  onPressed: () =>
                      deleteActivityHistoryEntry(context, ref, entry),
                  child: const Text('Delete'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      final language = AppLocalizations.of(
        tester.element(find.byType(DeleteConfirmationDialog)),
      );
      expect(
        tester
            .widget<DeleteConfirmationDialog>(
              find.byType(DeleteConfirmationDialog),
            )
            .message
            .contains(language.activityHistoryDeleteActiveMessage),
        false,
      );
      now = start;
      await tester.tap(find.text(language.commonDelete));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DeleteConfirmationDialog>(
              find.byType(DeleteConfirmationDialog),
            )
            .message
            .contains(language.activityHistoryDeleteActiveMessage),
        true,
      );
      await tester.tap(find.text(language.commonCancel));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}

import 'package:diabeatthis/common/family_sync/family_access_scope.dart';
import 'package:diabeatthis/common/family_sync/family_planning_controller.dart';
import 'package:diabeatthis/common/family_sync/firebase_activity_catalog_repository.dart';
import 'package:diabeatthis/common/planning/activity_catalog_repository.dart';
import 'package:diabeatthis/core/domain/model/activity.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/activity/data/drafts/activity_draft.dart';
import 'package:diabeatthis/features/activity/data/drafts/activity_schedule_draft.dart';
import 'package:diabeatthis/features/activity/presentation/widgets/activity_definition_sheet.dart';
import 'package:diabeatthis/features/activity/presentation/widgets/activity_schedule_setup.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';
import '../presentation/caregiver_audit_fixture.dart';

class RecordingCatalogRepository implements ActivityCatalogRepository {
  @override
  ActivityCatalogRepository beginEdit() => this;
  ActivityDraft? saved;
  ActivityScheduleDraft? schedule;
  @override
  Future<Activity?> saveDefinition(
    ActivityDraft draft, {
    ActivityScheduleDraft? schedule,
  }) async {
    saved = draft;
    this.schedule = schedule;
    return null;
  }

  @override
  Future<void> addSchedule(
    Activity activity,
    ActivityScheduleDraft schedule,
    int? duration,
  ) async {
    this.schedule = schedule;
  }
}

class RecordingCatalogFamily extends FamilyPlanningController {
  RecordingCatalogFamily(CaregiverAuditFixture f)
    : super(f.transport, () => f.uid, f.family.submissions) {
    uid = f.uid;
    owner = 'child';
    source = 'child-source';
    complete = true;
    rows.addAll(f.family.rows);
    rows['activities/5'] = {...rows['activities/5']!, 'revision': 1};
  }
  String? submitted;
  Map<String, dynamic>? values;
  @override
  Future<void> submit({
    required String type,
    required int? targetId,
    required Map<String, dynamic> values,
    required List<Map<String, dynamic>> baseRows,
    required String expectedSource,
    required String expectedUid,
  }) async {
    submitted = type;
    this.values = values;
  }
}

void main() {
  for (final existing in [false, true]) {
    testWidgets(
      'same definition form saves recurrence through source port, edit=$existing',
      (tester) async {
        final repo = RecordingCatalogRepository();
        final draft = existing
            ? const ActivityDraft.existing(
                id: 5,
                name: 'Swim',
                percentagePre: 20,
                percentagePost: 30,
                durationMinutes: 30,
              )
            : const ActivityDraft.draft(
                name: 'Swim',
                percentagePre: 20,
                percentagePost: 30,
                durationMinutes: 30,
              );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              activityCatalogRepositoryProvider.overrideWithValue(repo),
              activityCatalogMaximumDurationProvider.overrideWithValue(1440),
              databaseProvider.overrideWith(
                (_) => throw StateError('No patient DB'),
              ),
            ],
            child: localizedMaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showActivityDefinitionSheet(
                      context,
                      initialDraft: draft,
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final setup = tester.widget<ActivityScheduleSetup>(
          find.byType(ActivityScheduleSetup),
        );
        setup.onChanged(ActivityScheduleDraft(weekdays: {1, 3}));
        await tester.pumpAndSettle();
        await tester.tap(find.text(existing ? 'Zapisz' : 'Utwórz'));
        await tester.pumpAndSettle();
        expect(repo.saved?.name, 'Swim');
        expect(repo.schedule?.weekdays, {1, 3});
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  test(
    'stale activity revision rejects a form before any cloud submission',
    () async {
      final f = CaregiverAuditFixture();
      addTearDown(f.close);
      final family = RecordingCatalogFamily(f);
      addTearDown(family.dispose);
      final repository = FirebaseActivityCatalogRepository(
        FamilyAccessScope(family),
      );
      family.rows['activities/5'] = {
        ...family.rows['activities/5']!,
        'revision': 2,
      };
      await expectLater(
        repository.saveDefinition(
          const ActivityDraft.existing(
            id: 5,
            name: 'Stale',
            percentagePre: 20,
            percentagePost: 30,
            durationMinutes: 30,
          ),
        ),
        throwsStateError,
      );
      expect(family.submitted, isNull);
      await repository.beginEdit().saveDefinition(
        const ActivityDraft.existing(
          id: 5,
          name: 'New form',
          percentagePre: 20,
          percentagePost: 30,
          durationMinutes: 30,
        ),
      );
      expect(family.submitted, 'updateActivity');
    },
  );
  test(
    'catalog write uses cloud proposal and source change fails closed',
    () async {
      final f = CaregiverAuditFixture();
      addTearDown(f.close);
      final family = RecordingCatalogFamily(f);
      addTearDown(family.dispose);
      final repository = FirebaseActivityCatalogRepository(
        FamilyAccessScope(family),
      );
      const draft = ActivityDraft.draft(
        name: 'Swim',
        percentagePre: 20,
        percentagePost: 30,
        durationMinutes: 30,
      );
      await repository.saveDefinition(
        draft,
        schedule: ActivityScheduleDraft(weekdays: {1}),
      );
      expect(family.submitted, 'createActivity');
      expect((family.values!['schedule'] as Map)['weekdays'], [1]);
      family.submitted = null;
      family.source = 'changed';
      await expectLater(repository.saveDefinition(draft), throwsStateError);
      expect(family.submitted, isNull);
    },
  );
}

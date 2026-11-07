import 'package:diabeatthis/common/auth/google_account.dart';
import 'package:diabeatthis/common/auth/google_authentication_providers.dart';
import 'package:diabeatthis/common/family_sync/family_access_scope.dart';
import 'package:diabeatthis/common/family_sync/family_planning_view.dart';
import 'package:diabeatthis/common/family_sync/presentation/family_activity_schedules.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/core/domain/model/activity.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';
import '../planning/activity_catalog_reuse_test.dart'
    show RecordingCatalogFamily;
import '../presentation/caregiver_audit_fixture.dart';
import '../presentation/caregiver_day_navigation_test.dart'
    show AuditPlanningPage, AuditPlanningPageState;
import '../presentation/family_collection_fixtures.dart';

void main() {
  testWidgets(
    'caregiver recurring plan switch submits cloud activation without patient DB',
    (tester) async {
      final f = CaregiverAuditFixture();
      addTearDown(f.close);
      final family = RecordingCatalogFamily(f);
      addTearDown(family.dispose);
      final now = DateTime.now().millisecondsSinceEpoch;
      family.rows['activitySchedules/9'] = {
        ...mirrorRow('activitySchedules', 9, {
          'activity_id': 5,
          'weekdays': '1,3',
          'start_minute': 1020,
          'duration_minutes': 43,
          'confirmation_mode': 'before',
          'previous_day_minute': 1140,
          'valid_from': now,
          'valid_until': null,
          'enabled': 1,
        }),
        'revision': 1,
      };
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
              (_) => throw StateError('No patient DB'),
            ),
          ],
          child: localizedMaterialApp(
            home: Scaffold(
              body: FamilyActivitySchedules(
                scope: FamilyAccessScope(family),
                activity: const Activity(
                  id: 5,
                  name: 'Training',
                  percentagePre: 20,
                  percentagePost: 30,
                  durationMinutes: 43,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(family.submitted, 'setActivityScheduleEnabled');
      expect(family.values!['enabled'], false);
      expect(family.values!['effectiveFrom'], isA<int>());
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('skip opens a skip dialog and sends the matching operation', (
    tester,
  ) async {
    final f = CaregiverAuditFixture();
    addTearDown(f.close);
    final family = RecordingCatalogFamily(f);
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
        ],
        child: localizedMaterialApp(
          home: Scaffold(
            body: AuditPlanningPage(
              family: family,
              view: FamilyPlanningView.activities,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final state = tester.state<AuditPlanningPageState>(
      find.byType(AuditPlanningPage),
    );
    final lang = AppLocalizations.of(
      tester.element(find.byType(AuditPlanningPage)),
    );
    final edit = state.edit('skipActivity', targetId: 9);
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(AlertDialog, lang.activityScheduleNo),
      findsOneWidget,
    );
    expect(find.text(lang.familyPlanConfirm), findsNothing);
    await tester.tap(find.text(lang.familyPlanSend));
    await tester.pumpAndSettle();
    await edit;
    expect(family.submitted, 'skipActivity');
    expect(family.values, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

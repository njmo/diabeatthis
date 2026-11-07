import 'package:diabeatthis/common/auth/google_account.dart';
import 'package:diabeatthis/common/auth/google_authentication_providers.dart';
import 'package:diabeatthis/common/family_sync/family_access_scope.dart';
import 'package:diabeatthis/common/family_sync/presentation/family_activity_catalog_plan_card.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/activity/presentation/widgets/activity_definition_sheet.dart';
import 'package:diabeatthis/features/activity/presentation/widgets/activity_schedule_editor.dart';
import 'package:diabeatthis/features/activity/presentation/widgets/activity_schedule_setup.dart';
import 'package:diabeatthis/features/activity/presentation/widgets/activity_schedule_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';
import '../presentation/caregiver_audit_fixture.dart';
import 'activity_catalog_commands_test.dart'
    show definitionValues, scheduleValues;

void main() {
  for (final type in [
    'createActivity',
    'updateActivity',
    'createActivitySchedule',
  ]) {
    testWidgets(
      '$type identifies pending/rejected changes and reopens complete proposal',
      (tester) async {
        final f = CaregiverAuditFixture();
        addTearDown(f.close);
        final plan = <String, dynamic>{
          'id': 'proposal',
          'type': type,
          'targetId': type == 'createActivity' ? null : 5,
          'status': 'pending',
          'values': {
            'schedule': scheduleValues(),
            if (type != 'createActivitySchedule')
              'activity': definitionValues(),
          },
        };
        f.family.plans = [plan];
        final scope = FamilyAccessScope(f.family);
        Future<void> mount() => tester.pumpWidget(
          ProviderScope(
            overrides: [
              googleAccountProvider.overrideWith(
                (_) => Stream.value(
                  const GoogleAccount(
                    uid: 'parent',
                    email: 'parent@example.test',
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
                body: FamilyActivityCatalogPlanCard(scope: scope, plan: plan),
              ),
            ),
          ),
        );
        await mount();
        await tester.pumpAndSettle();
        expect(find.text('Swimming'), findsOneWidget);
        expect(find.byIcon(Icons.refresh), findsNothing);
        plan['status'] = 'rejected';
        await mount();
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.refresh), findsOneWidget);
        await tester.tap(find.byIcon(Icons.refresh));
        await tester.pumpAndSettle();
        if (type == 'createActivitySchedule') {
          expect(find.byType(ActivityScheduleSheet), findsOneWidget);
          expect(
            tester
                .widget<ActivityScheduleEditor>(
                  find.byType(ActivityScheduleEditor),
                )
                .value
                .weekdays,
            {1, 2, 3, 4, 5, 6, 7},
          );
        } else {
          expect(find.byType(ActivityDefinitionSheet), findsOneWidget);
          expect(
            tester
                .widget<TextFormField>(
                  find.byKey(const ValueKey('activity-name-field')),
                )
                .initialValue,
            'Swimming',
          );
          expect(
            tester
                .widget<ActivityScheduleSetup>(
                  find.byType(ActivityScheduleSetup),
                )
                .value
                ?.weekdays,
            {1, 2, 3, 4, 5, 6, 7},
          );
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

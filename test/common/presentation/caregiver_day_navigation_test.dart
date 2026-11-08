import 'package:diabeatthis/common/app_mode/application_device_mode.dart';
import 'package:diabeatthis/common/auth/google_account.dart';
import 'package:diabeatthis/common/auth/google_authentication_providers.dart';
import 'package:diabeatthis/common/family/family_providers.dart';
import 'package:diabeatthis/common/family_sync/family_planning_controller.dart';
import 'package:diabeatthis/common/family_sync/family_planning_view.dart';
import 'package:diabeatthis/common/family_sync/presentation/family_activity_log_card.dart';
import 'package:diabeatthis/common/family_sync/presentation/family_planning_page.dart';
import 'package:diabeatthis/common/family_sync/presentation/family_record_page.dart';
import 'package:diabeatthis/common/presentation/widgets/activity_log_card.dart';
import 'package:diabeatthis/core/data_sources/nightscout/providers/nightscout_repository_provider.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/meals/presentation/widgets/meal_list/meal_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';
import '../history/nightscout_statistics_fixture.dart';
import 'caregiver_audit_fixture.dart';
import 'family_collection_fixtures.dart';

class AuditPlanningPage extends FamilyPlanningPage {
  const AuditPlanningPage({
    super.key,
    required this.family,
    required super.view,
  }) : super(embedded: true);
  final FamilyPlanningController family;
  @override
  FamilyPlanningPageState createState() => AuditPlanningPageState();
}

class AuditPlanningPageState extends FamilyPlanningPageState {
  @override
  FamilyPlanningController get controller =>
      (widget as AuditPlanningPage).family;
  @override
  bool get enabled => true;
  @override
  void start() {}
  @override
  void initState() {
    listeningUid = 'parent';
    selectedDate = DateTime.fromMillisecondsSinceEpoch(familyRecordTime);
    super.initState();
  }
}

void main() {
  for (final type in ['meal', 'activity', 'activeActivity', 'expiredScope']) {
    testWidgets(
      'Home/history opens shared $type details and rejects stale scope',
      (tester) async {
        final fixture = CaregiverAuditFixture();
        addTearDown(fixture.close);
        if (type == 'activeActivity') {
          (fixture.family.rows['activityLogs/6']!['payload']
                  as Map)['ended_at'] =
              null;
        }
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              applicationDeviceModeProvider.overrideWith(
                (ref) async => ApplicationDeviceMode.caregiver,
              ),
              googleAccountProvider.overrideWith(
                (ref) => Stream.value(const GoogleAccount(uid: 'parent')),
              ),
              authenticatedFamilyTransportProvider.overrideWithValue(
                fixture.transport,
              ),
              databaseProvider.overrideWith(
                (ref) =>
                    throw StateError('Caregiver UI must not access patient DB'),
              ),
              nightscoutRepositoryProvider.overrideWith(
                (ref) async => StatisticsNightscout(),
              ),
            ],
            child: localizedMaterialApp(
              home: Scaffold(
                body: AuditPlanningPage(
                  family: fixture.family,
                  view: type == 'activeActivity'
                      ? FamilyPlanningView.home
                      : type == 'meal'
                      ? FamilyPlanningView.meals
                      : FamilyPlanningView.activities,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        if (type != 'activeActivity') {
          await tester.scrollUntilVisible(
            type == 'meal'
                ? find.byType(MealCard)
                : find.byType(ActivityLogCard),
            350,
            scrollable: find.byType(Scrollable).first,
          );
        }
        final VoidCallback callback;
        if (type == 'meal') {
          callback = tester.widget<MealCard>(find.byType(MealCard)).onTap;
        } else if (type != 'activeActivity') {
          callback = tester
              .widget<ActivityLogCard>(find.byType(ActivityLogCard))
              .onTap!;
        } else {
          callback = tester
              .widget<FamilyActivityLogCard>(find.byType(FamilyActivityLogCard))
              .onOpen!;
        }
        if (type == 'expiredScope') fixture.family.source = 'another-source';
        callback();
        await tester.pumpAndSettle();
        if (type == 'expiredScope') {
          expect(find.byType(FamilyRecordPage), findsNothing);
        } else {
          final page = tester.widget<FamilyRecordPage>(
            find.byType(FamilyRecordPage),
          );
          expect(page.kind, type == 'meal' ? 'meals' : 'activityLogs');
          expect(page.source, 'child-source');
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}

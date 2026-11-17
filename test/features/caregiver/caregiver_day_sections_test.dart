import 'package:diabeatthis/common/app_mode/application_device_mode.dart';
import 'package:diabeatthis/common/auth/google_account.dart';
import 'package:diabeatthis/common/auth/google_authentication_providers.dart';
import 'package:diabeatthis/common/family/family_providers.dart';
import 'package:diabeatthis/common/family_sync/family_planning_view.dart';
import 'package:diabeatthis/common/family_sync/presentation/family_activity_log_card.dart';
import 'package:diabeatthis/common/family_sync/presentation/family_planned_activity_card.dart';
import 'package:diabeatthis/common/family_sync/presentation/family_planned_meal_card.dart';
import 'package:diabeatthis/features/caregiver/presentation/widgets/day_presentations/caregiver_day_timeline_view.dart';
import 'package:diabeatthis/core/data_sources/nightscout/providers/nightscout_repository_provider.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/caregiver/presentation/widgets/caregiver_day_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../common/history/day_statistics_nightscout.dart';
import '../../common/presentation/caregiver_audit_fixture.dart';
import '../../common/presentation/caregiver_day_navigation_test.dart'
    show AuditPlanningPage;
import '../../common/presentation/family_collection_fixtures.dart';
import '../../helpers/localized_material_app.dart';

void main() {
  testWidgets(
    'Day keeps Nightscout statistics without appending record lists or background sync bars',
    (tester) async {
      final fixture = CaregiverAuditFixture();
      addTearDown(fixture.close);
      final ns = DayStatisticsNightscout(
        DateUtils.dateOnly(
          DateTime.fromMillisecondsSinceEpoch(familyRecordTime),
        ),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            googleAccountProvider.overrideWith(
              (ref) => Stream.value(const GoogleAccount(uid: 'parent')),
            ),
            applicationDeviceModeProvider.overrideWith(
              (ref) async => ApplicationDeviceMode.caregiver,
            ),
            authenticatedFamilyTransportProvider.overrideWithValue(
              fixture.transport,
            ),
            nightscoutRepositoryProvider.overrideWith((ref) async => ns),
            databaseProvider.overrideWith(
              (ref) => throw StateError('No patient DB'),
            ),
          ],
          child: localizedMaterialApp(
            home: Scaffold(
              body: AuditPlanningPage(
                family: fixture.family,
                view: FamilyPlanningView.day,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CaregiverDayTimelineView), findsOneWidget);
      await tester.drag(find.byType(ListView).first, const Offset(0, -10000));
      await tester.pumpAndSettle();
      expect(find.byType(FamilyActivityLogCard), findsNothing);
      expect(find.byType(FamilyPlannedActivityCard), findsNothing);
      expect(find.byType(FamilyPlannedMealCard), findsNothing);
      fixture.family.busy = true;
      fixture.family.notifyListeners();
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(find.byType(CaregiverDayTimelineView), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

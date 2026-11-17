import 'package:diabeatthis/common/app_mode/application_device_mode.dart';
import 'package:diabeatthis/common/auth/google_account.dart';
import 'package:diabeatthis/common/auth/google_authentication_providers.dart';
import 'package:diabeatthis/common/family/family_providers.dart';
import 'package:diabeatthis/common/family_sync/family_planning_view.dart';
import 'package:diabeatthis/common/l10n/language.dart';
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
    'actual caregiver Day binds date and refresh to NS independently of mirror records',
    (tester) async {
      final fixture = CaregiverAuditFixture();
      addTearDown(fixture.close);
      final date = DateUtils.dateOnly(
        DateTime.fromMillisecondsSinceEpoch(familyRecordTime),
      );
      final ns = DayStatisticsNightscout(date);
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
      final context = tester.element(find.byType(CaregiverDaySummary));
      expect(ns.glucoseWindows, hasLength(1));
      await tester.tap(find.byTooltip(context.lang.dayRefresh));
      await tester.pumpAndSettle();
      expect(ns.glucoseWindows, hasLength(2));
      await tester.tap(find.byTooltip(context.lang.dayPreviousDate));
      await tester.pumpAndSettle();
      expect(
        ns.glucoseWindows.last.$2,
        date.subtract(const Duration(microseconds: 1)),
      );
      fixture.family.clear();
      fixture.family.notifyListeners();
      await tester.pumpAndSettle();
      expect(find.byType(CaregiverDayTimelineView), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

import 'package:diabeatthis/common/app_mode/application_device_mode.dart';
import 'package:diabeatthis/common/auth/google_account.dart';
import 'package:diabeatthis/common/auth/google_authentication_providers.dart';
import 'package:diabeatthis/common/family_sync/family_planning_view.dart';
import 'package:diabeatthis/common/family_sync/presentation/family_planning_page.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/core/data_sources/nightscout/providers/nightscout_repository_provider.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/caregiver/data/caregiver_refresh_state.dart';
import 'package:diabeatthis/features/caregiver/data/caregiver_visible_state_provider.dart';
import 'package:diabeatthis/features/caregiver/presentation/widgets/caregiver_dashboard.dart';
import 'package:diabeatthis/features/caregiver/presentation/widgets/caregiver_dashboard_fab.dart';
import 'package:diabeatthis/features/dashboard/data/providers/time_now_provider.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/dashboard_bottom_bar.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/dashboard_fab.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../history/day_statistics_nightscout.dart';

void main() {
  testWidgets(
    'caregiver shares patient navigation while retaining family-only views and actions',
    (tester) async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            applicationDeviceModeProvider.overrideWith(
              (ref) async => ApplicationDeviceMode.caregiver,
            ),
            nightscoutRepositoryProvider.overrideWith(
              (ref) async => DayStatisticsNightscout(DateTime(2026, 11, 6)),
            ),
            databaseProvider.overrideWithValue(db),
            googleAccountProvider.overrideWith(
              (ref) => Stream.value(
                const GoogleAccount(uid: 'parent', displayName: 'Parent'),
              ),
            ),
            caregiverVisibleStateProvider.overrideWithValue(
              const CaregiverRefreshState(),
            ),
            timeNowProvider.overrideWith(
              (ref) => Stream.value(DateTime(2026, 11, 6)),
            ),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const CaregiverDashboard(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final lang = AppLocalizations.of(
        tester.element(find.byType(CaregiverDashboard)),
      );
      expect(find.byType(DashboardBottomBar), findsOneWidget);
      expect(find.byType(CaregiverDashboardFab), findsOneWidget);
      expect(find.byType(DashboardFAB), findsNothing);
      final state = tester.state(find.byType(FamilyPlanningPage));
      await tester.tap(find.byTooltip(lang.dashboardDayTab));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FamilyPlanningPage>(find.byType(FamilyPlanningPage)).view,
        FamilyPlanningView.day,
      );
      expect(tester.state(find.byType(FamilyPlanningPage)), same(state));
      await tester.tap(find.byTooltip(lang.dashboardHistoryTab));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FamilyPlanningPage>(find.byType(FamilyPlanningPage)).view,
        FamilyPlanningView.meals,
      );
      await tester.tap(find.byTooltip(lang.managementActivitiesTab));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FamilyPlanningPage>(find.byType(FamilyPlanningPage)).view,
        FamilyPlanningView.activities,
      );
      await tester.tap(find.byTooltip(lang.dashboardCatalogTab));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FamilyPlanningPage>(find.byType(FamilyPlanningPage)).view,
        FamilyPlanningView.ingredients,
      );
      await tester.tap(find.byTooltip(lang.managementActivitiesTab));
      await tester.pumpAndSettle();
      expect(
        tester.widget<FamilyPlanningPage>(find.byType(FamilyPlanningPage)).view,
        FamilyPlanningView.activityCatalog,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

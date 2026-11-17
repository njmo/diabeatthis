import 'package:diabeatthis/common/app_mode/application_device_mode.dart';
import 'package:diabeatthis/common/auth/google_account.dart';
import 'package:diabeatthis/common/auth/google_authentication_providers.dart';
import 'package:diabeatthis/common/presentation/day/day_history_statistics.dart';
import 'package:diabeatthis/core/data_sources/nightscout/providers/nightscout_repository_provider.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/caregiver/presentation/widgets/caregiver_day_summary.dart';
import 'package:diabeatthis/features/caregiver/presentation/widgets/day_presentations/caregiver_day_device_age_card.dart';
import 'package:diabeatthis/features/caregiver/presentation/widgets/day_presentations/caregiver_day_glucose_chart.dart';
import 'package:diabeatthis/features/caregiver/presentation/widgets/day_presentations/caregiver_day_timeline_view.dart';
import 'package:diabeatthis/features/caregiver/presentation/widgets/day_presentations/caregiver_night_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../common/history/day_statistics_nightscout.dart';
import '../../helpers/localized_material_app.dart';

void main() {
  testWidgets('caregiver day renders timeline view directly with night and 24h cards', (tester) async {
    final selected = DateTime(2026, 11, 5);
    final repository = DayStatisticsNightscout(selected);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          googleAccountProvider.overrideWith(
            (ref) => Stream.value(const GoogleAccount(uid: 'parent')),
          ),
          applicationDeviceModeProvider.overrideWith(
            (ref) async => ApplicationDeviceMode.caregiver,
          ),
          nightscoutRepositoryProvider.overrideWith(
            (ref) async => repository,
          ),
          databaseProvider.overrideWith(
            (ref) => throw StateError('No local patient database'),
          ),
        ],
        child: localizedMaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CaregiverDaySummary(date: selected),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Renders Timeline View directly
    expect(find.byType(CaregiverDayTimelineView), findsOneWidget);
    expect(find.byType(CaregiverDayDeviceAgeCard), findsOneWidget);
    expect(find.byType(CaregiverNightSummaryCard), findsOneWidget);
    expect(find.byType(CaregiverDayGlucoseChart), findsOneWidget);

    // No classic or legacy view
    expect(find.byType(DayHistoryStatistics), findsNothing);

    // No temporary prototype selector tabs
    expect(find.text('🌟 W1: Hero & Segmenty'), findsNothing);
    expect(find.text('⏱️ W2: Oś czasu 24h'), findsNothing);
    expect(find.text('🗂️ W3: Modułowy akordeon'), findsNothing);
  });
}

import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/widgets/nutrition_metric_tile.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/caregiver/data/caregiver_nightscout_snapshot.dart';
import 'package:diabeatthis/features/caregiver/data/caregiver_refresh_state.dart';
import 'package:diabeatthis/features/caregiver/data/caregiver_visible_state_provider.dart';
import 'package:diabeatthis/features/caregiver/presentation/widgets/caregiver_nightscout_panel.dart';
import 'package:diabeatthis/features/dashboard/data/providers/blood_sugar_readings_list_provider.dart';
import 'package:diabeatthis/features/dashboard/data/providers/time_now_provider.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/dashboard_glucose_reading.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/device_status_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/caregiver/caregiver_reading_isolation_test.dart'
    show ForbiddenPatientReadings;
import '../../helpers/device_status_factory.dart';

void main() {
  for (final dark in [false, true]) {
    for (final hasGlucose in [false, true]) {
      testWidgets(
        'shared caregiver metrics preserve colors and CGM source: dark=$dark glucose=$hasGlucose',
        (tester) async {
          final now = DateTime.now();
          final device = testDeviceStatus(
            date: now.subtract(const Duration(minutes: 8)),
            iob: 1,
            cob: 2,
            tick: '0',
            bg: 250,
            carbsReq: 20,
          );
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                databaseProvider.overrideWith(
                  (_) => throw StateError('No patient database'),
                ),
                bloodSugarReadingsListProvider.overrideWith(
                  ForbiddenPatientReadings.new,
                ),
                timeNowProvider.overrideWith((_) => Stream.value(now)),
                caregiverVisibleStateProvider.overrideWithValue(
                  CaregiverRefreshState(
                    snapshot: CaregiverNightscoutSnapshot(
                      glucose: hasGlucose
                          ? [
                              Glucose(
                                externalId: 'cgm',
                                source: GlucoseSource.cloud,
                                date: now,
                                sgv: 123,
                                direction: 'Flat',
                              ),
                            ]
                          : [],
                      deviceStatus: device,
                      targetFetched: true,
                      hasFailures: false,
                    ),
                  ),
                ),
              ],
              child: MaterialApp(
                locale: const Locale('en'),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                theme: ThemeData(
                  brightness: dark ? Brightness.dark : Brightness.light,
                ),
                home: const Scaffold(body: CaregiverNightscoutPanel(showMetrics: true)),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(DeviceStatusDashboard), findsOneWidget);
          final reading = tester.widget<DashboardGlucoseReading>(
            find.byType(DashboardGlucoseReading),
          );
          expect(reading.value, hasGlucose ? 123 : null);
          final tiles = tester
              .widgetList<NutritionMetricTile>(find.byType(NutritionMetricTile))
              .toList();
          expect(tiles[0].iconColor, Color(dark ? 0xFF80D8F7 : 0xFF08799E));
          expect(tiles[1].iconColor, Color(dark ? 0xFFF3C96A : 0xFF986500));
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}

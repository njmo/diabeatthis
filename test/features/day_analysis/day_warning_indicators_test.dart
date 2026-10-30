import 'package:diabeatthis/common/history/glucose_period_summary.dart';
import 'package:diabeatthis/common/history/insulin_basal_summary.dart';
import 'package:diabeatthis/common/history/insulin_bolus_summary.dart';
import 'package:diabeatthis/common/widgets/data_warning_indicator.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_context.dart';
import 'package:diabeatthis/features/day_analysis/domain/use_cases/build_day_context_use_case.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_activity_card.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_basal_rows.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_device_age_card.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_glucose_card.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_insulin_card.dart';
import 'package:diabeatthis/features/day_analysis/presentation/widgets/day_meals_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';
import 'build_day_context_use_case_test.dart' show emptyMeals;

void main() {
  Future<void> show(WidgetTester tester, Widget child) => tester.pumpWidget(
    localizedMaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  testWidgets(
    'CGM gaps explain missing reading counts on tap; complete history has no warning',
    (tester) async {
      final start = DateTime(2026, 9, 11);
      final reading = Glucose(
        externalId: null,
        source: GlucoseSource.cloud,
        date: start,
        sgv: 120,
        direction: '',
      );
      for (final minutes in [50, 5]) {
        await show(
          tester,
          DayGlucoseCard(
            title: 'Glikemia',
            summary: GlucosePeriodSummary.calculate(
              [reading],
              start,
              start.add(Duration(minutes: minutes)),
            ),
          ),
        );
        if (minutes == 50) {
          expect(
            find.text('Brakujące odczyty CGM: 9 z 10 (90,0%).'),
            findsNothing,
          );
          await tester.tap(find.byType(DataWarningIndicator));
          await tester.pump(const Duration(milliseconds: 300));
          expect(
            find.text('Brakujące odczyty CGM: 9 z 10 (90,0%).'),
            findsOneWidget,
          );
          await tester.pump(const Duration(seconds: 9));
        } else {
          expect(find.byType(DataWarningIndicator), findsNothing);
        }
      }
    },
  );

  testWidgets('empty successful activity source is not a failure', (
    tester,
  ) async {
    await show(tester, const DayActivityCard(activities: []));
    expect(find.byType(DataWarningIndicator), findsNothing);
    await show(tester, const DayActivityCard(activities: null));
    expect(find.byType(DataWarningIndicator), findsOneWidget);
  });

  testWidgets(
    'device warnings distinguish missing change from a failed source and preserve zero age',
    (tester) async {
      for (final fail in [false, true]) {
        final day = await BuildDayContextUseCase(
          now: () => DateTime(2026, 9, 11, 12),
          loadGlucose: (_, _) async => [],
          loadTreatments: (_, _) async => [],
          loadMeals: (_, _) async => emptyMeals,
          loadLowTreatments: (_, _) async => [],
          loadActivities: (_, _) async => [],
          loadSensorAge: (_) async {
            if (fail) {
              throw StateError('offline');
            }
            return null;
          },
          loadPodAge: (_) async => Duration.zero,
        )();
        expect(day.failedSources, fail ? {DayDataSource.sensorAge} : isEmpty);
        await show(tester, DayDeviceAgeCard(day: day));
        final indicator = tester.widget<DataWarningIndicator>(
          find.byType(DataWarningIndicator),
        );
        expect(
          indicator.message,
          fail
              ? 'Wiek sensora: Nie udało się pobrać danych. Spróbuj odświeżyć.'
              : 'Wiek sensora: Brak zapisu wymiany',
        );
        expect(indicator.message, isNot(contains('Wiek poda')));
        await show(tester, DayMealsCard(day: day));
        expect(find.byType(DataWarningIndicator), findsNothing);
      }
    },
  );

  testWidgets(
    'partial basal is flagged without turning recorded zero into missing insulin',
    (tester) async {
      const boluses = InsulinBolusSummary(
        manualCount: 0,
        manualUnits: 0,
        otherCount: 0,
        otherUnits: 0,
      );
      for (final (covered, isNight) in [
        (30, false),
        (60, false),
        (30, true),
        (60, true),
      ]) {
        final basal = InsulinBasalSummary(
          units: 0,
          profileUnits: 0,
          addedUnits: 0,
          reducedUnits: 0,
          coveredDuration: Duration(minutes: covered),
          duration: const Duration(hours: 1),
          gaps: [],
        );
        await show(
          tester,
          DayInsulinCard(summary: boluses, basal: basal, isNight: isNight),
        );
        if (covered == 30) {
          final warning = tester.widget<DataWarningIndicator>(
            find.byType(DataWarningIndicator),
          );
          expect(
            warning.message,
            contains('Brakuje danych z 30 min analizowanego okresu.'),
          );
          final details = find.byType(ExpansionTile);
          await tester.ensureVisible(details);
          await tester.tap(details);
          await tester.pumpAndSettle();
          expect(
            find.descendant(
              of: find.byType(DayBasalRows),
              matching: find.text('Suma częściowa bazy i zapisanych bolusów'),
            ),
            findsOneWidget,
          );
        } else {
          expect(find.byType(DataWarningIndicator), findsNothing);
        }
        expect(find.text('0,00 U'), findsWidgets);
      }
    },
  );
}

import 'package:diabeatthis/common/history/insulin_basal_summary.dart';
import 'package:diabeatthis/common/history/insulin_bolus_summary.dart';
import 'package:diabeatthis/common/presentation/day/day_night_summary_card.dart';
import 'package:diabeatthis/common/widgets/data_warning_indicator.dart';
import 'package:diabeatthis/features/caregiver/presentation/widgets/day_presentations/caregiver_day_timeline_view.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_context.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  testWidgets(
    'night shortcut warns about missing boluses even with complete basal',
    (tester) async {
      final start = DateTime(2026, 11, 5);
      final basal = InsulinBasalSummary(
        units: 1,
        profileUnits: 1,
        addedUnits: 0,
        reducedUnits: 0,
        coveredDuration: const Duration(hours: 8),
        duration: const Duration(hours: 8),
        gaps: [],
      );
      final day = DayContext(
        start: start,
        asOf: start,
        builtAt: start,
        glucose: null,
        nightGlucose: null,
        boluses: null,
        nightBoluses: null,
        basal: basal,
        nightBasal: basal,
        meals: null,
        lowTreatments: null,
        activities: null,
        failedSources: {},
      );
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: DayNightSummaryCard(day: day)),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final warning = tester
          .widgetList<DataWarningIndicator>(find.byType(DataWarningIndicator))
          .singleWhere((warning) => warning.compact);
      expect(warning.message, contains('Bolusy łącznie'));
      expect(warning.message, contains('Nie udało się pobrać'));
      expect(tester.takeException(), isNull);
    },
  );
  const boluses = InsulinBolusSummary(
    manualCount: 0,
    manualUnits: 0,
    otherCount: 0,
    otherUnits: 0,
  );
  for (final covered in <int?>[null, 0, 30, 60]) {
    testWidgets(
      'compact insulin warnings distinguish coverage=$covered from failed fetch',
      (tester) async {
        final start = DateTime(2026, 11, 5);
        final basal = covered == null
            ? null
            : InsulinBasalSummary(
                units: 0,
                profileUnits: 0,
                addedUnits: 0,
                reducedUnits: 0,
                coveredDuration: Duration(minutes: covered),
                duration: const Duration(hours: 1),
                gaps: [],
              );
        final day = DayContext(
          start: start,
          asOf: start.add(const Duration(hours: 1)),
          builtAt: start,
          glucose: null,
          nightGlucose: null,
          boluses: boluses,
          nightBoluses: boluses,
          basal: basal,
          nightBasal: basal,
          meals: null,
          lowTreatments: null,
          activities: null,
          failedSources: {},
        );
        await tester.pumpWidget(
          ProviderScope(
            child: localizedMaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: CaregiverDayTimelineView(day: day),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final warnings = tester
            .widgetList<DataWarningIndicator>(find.byType(DataWarningIndicator))
            .where((w) => w.compact)
            .toList();
        if (covered == 60) {
          expect(warnings, isEmpty);
        } else {
          expect(warnings, hasLength(2));
          for (final warning in warnings) {
            if (covered == null) {
              expect(warning.message, contains('Nie udało się pobrać'));
            } else {
              expect(
                warning.message,
                contains(
                  covered == 0
                      ? 'Brakuje danych z 1 h'
                      : 'Brakuje danych z 30 min',
                ),
              );
              expect(warning.message, isNot(contains('Nie udało się pobrać')));
            }
          }
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}

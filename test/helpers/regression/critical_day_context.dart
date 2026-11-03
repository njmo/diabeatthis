import 'package:diabeatthis/common/history/insulin_basal_summary.dart';
import 'package:diabeatthis/common/history/insulin_bolus_summary.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_activity_summary.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_context.dart';
import 'package:diabeatthis/features/day_analysis/domain/models/day_meal_summary.dart';
import 'package:diabeatthis/features/low_treatment/domain/models/recorded_low_treatment.dart';

DayContext criticalDayContext({
  List<RecordedLowTreatment>? lows = const [],
  DayMealSummary? meals = const DayMealSummary(
    count: 2,
    plannedFallbackCount: 0,
    missingSnapshotCount: 0,
    netCarbs: 45,
    fat: 12,
    protein: 20,
  ),
  bool basalAvailable = true,
  bool basalObserved = true,
  bool bolusesAvailable = true,
  List<DayActivitySummary>? activities = const [],
}) {
  final start = DateTime(2026, 9, 1);
  return DayContext(
    start: start,
    asOf: DateTime(2026, 9, 2),
    builtAt: DateTime(2026, 9, 2, 8),
    glucose: null,
    nightGlucose: null,
    basal: !basalAvailable
        ? null
        : InsulinBasalSummary(
            units: basalObserved ? 4 : 0,
            profileUnits: basalObserved ? 5 : 0,
            addedUnits: 1,
            reducedUnits: 2,
            coveredDuration: basalObserved
                ? const Duration(days: 1)
                : Duration.zero,
            duration: const Duration(days: 1),
            gaps: [],
          ),
    nightBasal: InsulinBasalSummary(
      units: 1,
      profileUnits: 1,
      addedUnits: 0,
      reducedUnits: 0,
      coveredDuration: const Duration(hours: 8),
      duration: const Duration(hours: 8),
      gaps: [],
    ),
    boluses: !bolusesAvailable
        ? null
        : const InsulinBolusSummary(
            manualCount: 1,
            manualUnits: 2,
            otherCount: 1,
            otherUnits: 1,
          ),
    nightBoluses: const InsulinBolusSummary(
      manualCount: 1,
      manualUnits: 1,
      otherCount: 0,
      otherUnits: 0,
    ),
    meals: meals,
    lowTreatments: lows,
    activities: activities,
    sensorAge: const Duration(hours: 49, minutes: 30),
    podAge: const Duration(hours: 6),
    failedSources: const {},
  );
}

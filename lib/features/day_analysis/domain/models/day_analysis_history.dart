import '../../../../core/domain/model/device_status.dart';
import '../../../../core/domain/model/glucose.dart';
import '../../../../core/domain/model/treatment_base.dart';
import '../../../low_treatment/domain/models/recorded_low_treatment.dart';
import '../../../meal_analysis/domain/models/meal_activity_context.dart';
import 'day_analysis_meal.dart';

/// On-demand event history. Not part of the immutable accepted aggregate snapshot.
class DayAnalysisHistory {
  final DateTime start;
  final DateTime end;
  final DateTime builtAt;
  final List<Glucose>? glucose;
  final List<DeviceStatus>? statuses;
  final List<Treatment>? treatments;
  final List<DayAnalysisMeal>? meals;
  final List<RecordedLowTreatment>? lows;
  final List<MealActivityContext>? activities;
  final Set<String> failures;
  final Set<int> failedMealIds;

  DayAnalysisHistory({
    required this.start,
    required this.end,
    required this.builtAt,
    required List<Glucose>? glucose,
    required List<DeviceStatus>? statuses,
    required List<Treatment>? treatments,
    required List<DayAnalysisMeal>? meals,
    required List<RecordedLowTreatment>? lows,
    required List<MealActivityContext>? activities,
    required Set<String> failures,
    Set<int> failedMealIds = const {},
  }) : glucose = glucose == null ? null : List.unmodifiable(glucose),
       statuses = statuses == null ? null : List.unmodifiable(statuses),
       treatments = treatments == null ? null : List.unmodifiable(treatments),
       meals = meals == null ? null : List.unmodifiable(meals),
       lows = lows == null ? null : List.unmodifiable(lows),
       activities = activities == null ? null : List.unmodifiable(activities),
       failures = Set.unmodifiable(failures),
       failedMealIds = Set.unmodifiable(failedMealIds);
}

import '../../../../common/history/glucose_period_summary.dart';
import '../../../../common/history/insulin_basal_summary.dart';
import '../../../../common/history/insulin_bolus_summary.dart';
import '../../../../core/domain/model/device_status.dart';
import '../../../../core/domain/model/glucose.dart';
import '../../../../core/domain/model/treatment_base.dart';
import '../../../low_treatment/domain/models/recorded_low_treatment.dart';
import 'extended_carb_overlap.dart';
import 'meal_activity_observation.dart';
import 'recorded_meal_context.dart';

/// Facts within a bounded post-meal window. Completion of time does not imply
/// complete source history, nor attribution of a glucose change to this meal.
class MealOutcomeContext {
  final DateTime mealTime;
  final DateTime observedUntil;
  final DateTime expectedUntil;
  final DateTime builtAt;
  final GlucosePeriodSummary glucoseSummary;
  final InsulinBasalSummary basal;
  final InsulinBolusSummary boluses;
  final List<Glucose> glucose;
  final List<DeviceStatus> deviceStatuses;
  final List<Treatment> treatments;
  final List<RecordedLowTreatment> lowTreatments;
  final List<MealActivityObservation> activities;

  /// Null means this optional local history source could not be loaded.
  final List<RecordedMealContext>? subsequentMeals;
  final List<ExtendedCarbOverlap> extendedCarbs;
  final DateTime treatmentHistoryStart;

  MealOutcomeContext({
    required this.mealTime,
    required this.observedUntil,
    required this.expectedUntil,
    required this.builtAt,
    required this.glucoseSummary,
    required this.basal,
    required this.boluses,
    required List<Glucose> glucose,
    required List<DeviceStatus> deviceStatuses,
    required List<Treatment> treatments,
    required List<RecordedLowTreatment> lowTreatments,
    required List<MealActivityObservation> activities,
    required List<RecordedMealContext>? subsequentMeals,
    required List<ExtendedCarbOverlap> extendedCarbs,
    required this.treatmentHistoryStart,
  }) : glucose = List.unmodifiable(glucose),
       deviceStatuses = List.unmodifiable(deviceStatuses),
       treatments = List.unmodifiable(treatments),
       lowTreatments = List.unmodifiable(lowTreatments),
       activities = List.unmodifiable(activities),
       subsequentMeals = subsequentMeals == null
           ? null
           : List.unmodifiable(subsequentMeals),
       extendedCarbs = List.unmodifiable(extendedCarbs);

  bool get isTimeWindowComplete => !observedUntil.isBefore(expectedUntil);
}

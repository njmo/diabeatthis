import '../../../../common/history/glucose_period_summary.dart';
import '../../../../common/history/insulin_basal_summary.dart';
import '../../../../common/history/insulin_bolus_summary.dart';
import '../../../../core/domain/model/aaps_prediction_snapshot.dart';
import '../../../../core/domain/model/device_status.dart';
import '../../../../core/domain/model/glucose.dart';
import '../../../../core/domain/model/meal_macro_summary.dart';
import '../../../../core/domain/model/treatment_base.dart';
import '../../../low_treatment/domain/models/recorded_low_treatment.dart';
import 'before_meal_windows.dart';
import 'extended_carb_plan_context.dart';
import 'meal_activity_context.dart';
import 'recorded_meal_context.dart';

enum BeforeMealSource {
  glucose,
  deviceStatus,
  treatments,
  meals,
  lowTreatments,
  activities,
  podAge,
}

/// Event-time reconstruction using currently available history. This is not an
/// audit of exactly what had reached the phone at cutoff (upload times and all
/// revisions are not retained). No advice, dose calculation or persisted copy.
class BeforeMealContext {
  final DateTime asOf;
  final DateTime builtAt;
  final int? mealId;

  /// Supplied explicitly by the caller for the meal being considered.
  final MealMacroSummary? macros;
  final BeforeMealWindows windows;
  final List<Glucose>? glucose;
  final GlucosePeriodSummary? glucoseSummary;
  final DeviceStatus? latestDeviceStatus;
  final AapsPredictionSnapshot? predictions;
  final InsulinBasalSummary? basal;
  final InsulinBolusSummary? boluses;
  final List<Treatment>? treatments;
  final List<ExtendedCarbPlanContext>? extendedCarbPlans;
  final List<RecordedMealContext>? priorMeals;
  final List<RecordedLowTreatment>? lowTreatments;
  final List<MealActivityContext>? activities;
  final Duration? podAge;
  final Set<BeforeMealSource> failedSources;

  BeforeMealContext({
    required this.asOf,
    required this.builtAt,
    required this.mealId,
    required this.macros,
    required this.windows,
    required List<Glucose>? glucose,
    required this.glucoseSummary,
    required this.latestDeviceStatus,
    required this.predictions,
    required this.basal,
    required this.boluses,
    required List<Treatment>? treatments,
    required List<ExtendedCarbPlanContext>? extendedCarbPlans,
    required List<RecordedMealContext>? priorMeals,
    required List<RecordedLowTreatment>? lowTreatments,
    required List<MealActivityContext>? activities,
    required this.podAge,
    required Set<BeforeMealSource> failedSources,
  }) : glucose = glucose == null ? null : List.unmodifiable(glucose),
       treatments = treatments == null ? null : List.unmodifiable(treatments),
       extendedCarbPlans = extendedCarbPlans == null
           ? null
           : List.unmodifiable(extendedCarbPlans),
       priorMeals = priorMeals == null ? null : List.unmodifiable(priorMeals),
       lowTreatments = lowTreatments == null
           ? null
           : List.unmodifiable(lowTreatments),
       activities = activities == null ? null : List.unmodifiable(activities),
       failedSources = Set.unmodifiable(failedSources);

  Glucose? get latestCgm =>
      glucose == null || glucose!.isEmpty ? null : glucose!.last;

  /// A stale sample remains visible as evidence, but is not a fresh CGM input.
  bool get hasFreshCgm =>
      latestCgm != null &&
      asOf.difference(latestCgm!.date) < const Duration(minutes: 10);
}

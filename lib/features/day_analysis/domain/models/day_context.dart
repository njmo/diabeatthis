import '../../../../common/history/glucose_period_summary.dart';
import '../../../../common/history/insulin_basal_summary.dart';
import '../../../../common/history/insulin_bolus_summary.dart';
import '../../../../core/domain/model/bolus_wizard.dart';
import '../../../low_treatment/domain/models/recorded_low_treatment.dart';
import 'day_activity_summary.dart';
import 'day_meal_summary.dart';

enum DayDataSource {
  glucose,
  deviceStatus,
  treatments,
  meals,
  lowTreatments,
  activities,
  sensorAge,
  podAge,
}

/// An on-demand draft. Null means unavailable, not an empty or zero result.
class DayContext {
  final DateTime start;
  final DateTime asOf;
  final DateTime builtAt;
  final GlucosePeriodSummary? glucose;
  final GlucosePeriodSummary? nightGlucose;
  final InsulinBasalSummary? basal;
  final InsulinBasalSummary? nightBasal;
  final InsulinBolusSummary? boluses;
  final InsulinBolusSummary? nightBoluses;
  final DayMealSummary? meals;

  /// Already fetched day records shared with inline review; never persisted.
  final List<BolusWizard>? wizards;
  final List<RecordedLowTreatment>? lowTreatments;
  final List<DayActivitySummary>? activities;

  /// Nightscout Sensor Change, evaluated at asOf.
  final Duration? sensorAge;

  /// Nightscout Insulin Change; interpreted as pod age for Omnipod DASH.
  final Duration? podAge;
  final Set<DayDataSource> failedSources;

  /// Completion concerns elapsed calendar time, not source completeness.
  bool get isComplete =>
      !asOf.isBefore(DateTime(start.year, start.month, start.day + 1));

  DayContext({
    this.basal,
    this.nightBasal,
    this.sensorAge,
    this.podAge,
    required this.start,
    required this.asOf,
    required this.builtAt,
    required this.glucose,
    required this.nightGlucose,
    required this.boluses,
    required this.nightBoluses,
    required this.meals,
    List<BolusWizard>? wizards,
    required List<RecordedLowTreatment>? lowTreatments,
    required List<DayActivitySummary>? activities,
    required Set<DayDataSource> failedSources,
  }) : wizards = wizards == null ? null : List.unmodifiable(wizards),
       lowTreatments = lowTreatments == null
           ? null
           : List.unmodifiable(lowTreatments),
       activities = activities == null ? null : List.unmodifiable(activities),
       failedSources = Set.unmodifiable(failedSources);
}

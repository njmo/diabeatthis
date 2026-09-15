import 'dart:convert';

import '../models/accepted_day_summary.dart';
import '../models/day_dml_document.dart';
import '../models/day_summary_snapshot.dart';

/// Exports only the accepted document, without fetching or reconstructing history.
class BuildDayDmlUseCase {
  const BuildDayDmlUseCase();

  DayDmlDocument call(
    AcceptedDaySummary accepted, {
    bool hasEventHistory = false,
  }) {
    final day = accepted.snapshot;
    final output = StringBuffer('DML/${DayDmlDocument.version}\n');
    final ids = <String>{};
    void section(String name, String id, Map<String, Object?> fields) {
      ids.add(id);
      output.writeln('$name ${jsonEncode({'id': id, ...fields})}');
    }

    num? metric(DaySummaryMetric key) {
      final value = day.observedMetric(key);
      return value != null && value.isFinite ? value : null;
    }

    Map<String, Object?>? time(DateTime? instant) => instant == null
        ? null
        : {
            'utc': instant.toUtc().toIso8601String(),
            // This wall-clock value is already shifted by the archived offset.
            'local': day
                .displayTime(instant)
                .toIso8601String()
                .replaceFirst(RegExp(r'Z$'), ''),
          };

    section('DAY', 'day', {
      'date': day.dayKey,
      'status': 'accepted',
      'summary_version': DaySummarySnapshot.schemaVersion,
      'as_of': time(day.asOf),
      'built_at_utc': day.builtAt.toUtc().toIso8601String(),
      'accepted_at_utc': accepted.acceptedAt.toUtc().toIso8601String(),
      'utc_offset_minutes_at_day_start': day.utcOffsetMinutes,
    });
    final limitations = [...day.limitations]..sort();
    section('QUALITY', 'quality', {
      'limitations': limitations,
      'treatment_history_completeness': 'unknown',
      'unavailable_context': [
        if (!hasEventHistory) ...[
          'cgm_series',
          'meal_macros_and_timing',
          'night_lead_in',
          'ecarbs_schedule',
          'iob_cob_series',
          'activity_timeline',
        ],
        'previous_day',
        'aaps_profile',
      ],
    });
    section('GLUCOSE', 'glucose', {
      'mean_mg_dl': metric(DaySummaryMetric.glucoseMean),
      'max_mg_dl': metric(DaySummaryMetric.glucoseMax),
      'below70_pct': metric(DaySummaryMetric.glucoseLowPercent),
      'in70_180_pct': metric(DaySummaryMetric.glucoseInRangePercent),
      'above180_pct': metric(DaySummaryMetric.glucoseHighPercent),
      'coverage_pct': metric(DaySummaryMetric.glucoseCoveragePercent),
    });
    section('INSULIN', 'insulin', {
      'total_est_units': metric(DaySummaryMetric.totalInsulinUnits),
      'basal_est_units': metric(DaySummaryMetric.basalUnits),
      'basal_above_profile_units': metric(DaySummaryMetric.basalAddedUnits),
      'basal_below_profile_units': metric(DaySummaryMetric.basalReducedUnits),
      'basal_coverage_pct': metric(DaySummaryMetric.basalCoveragePercent),
      'bolus_total_units': metric(DaySummaryMetric.bolusUnits),
      'smb_units': metric(DaySummaryMetric.smbUnits),
      'smb_count': metric(DaySummaryMetric.smbCount),
    });
    section('NIGHT', 'night', {
      'start': time(day.nightStart),
      'end': time(day.nightEnd),
      'mean_mg_dl': metric(DaySummaryMetric.nightGlucoseMean),
      'in70_180_pct': metric(DaySummaryMetric.nightInRangePercent),
      'cgm_coverage_pct': metric(DaySummaryMetric.nightGlucoseCoveragePercent),
      'basal_est_units': metric(DaySummaryMetric.nightBasalUnits),
      'basal_coverage_pct': metric(DaySummaryMetric.nightBasalCoveragePercent),
      'bolus_total_units': metric(DaySummaryMetric.nightBolusUnits),
      'smb_units': metric(DaySummaryMetric.nightSmbUnits),
      'smb_count': metric(DaySummaryMetric.nightSmbCount),
      'lead_in': hasEventHistory
          ? 'see MEAL, CGM, NIGHT_COURSE and HISTORY availability'
          : null,
    });
    section('MEALS', 'meals', {
      'count': metric(DaySummaryMetric.mealCount),
      'net_carbs_g': metric(DaySummaryMetric.netCarbsGrams),
      'protein_g': metric(DaySummaryMetric.proteinGrams),
      'fat_g': metric(DaySummaryMetric.fatGrams),
    });
    section('LOW_TREATMENTS', 'low_treatments', {
      'confirmed_count': metric(DaySummaryMetric.lowTreatmentCount),
      'confirmed_carbs_g': metric(DaySummaryMetric.lowTreatmentCarbsGrams),
    });
    section('ACTIVITY', 'activity', {
      'minutes': metric(DaySummaryMetric.activityMinutes),
    });
    section('DEVICES', 'devices', {
      'sensor_age_minutes_at_as_of': metric(DaySummaryMetric.sensorAgeMinutes),
      'pod_age_minutes_at_as_of': metric(DaySummaryMetric.podAgeMinutes),
    });
    // Review rows are reconciliation records, not a food or insulin timeline.
    // Grouping by local meal alias preserves multiple calculator links to one meal.
    final review = [...day.review]
      ..sort((a, b) {
        final order = a.occurredAt.compareTo(b.occurredAt);
        if (order != 0) return order;
        return jsonEncode(a.toJson()).compareTo(jsonEncode(b.toJson()));
      });
    final mealIds = review.map((r) => r.mealId).nonNulls.toSet().toList()
      ..sort();
    for (var i = 0; i < review.length; i++) {
      final row = review[i];
      section('REVIEW', 'review:${i + 1}', {
        'at': time(row.occurredAt),
        'kind': row.kind == DaySummaryReviewKind.meal
            ? 'wizard'
            : 'carbohydrate_entry',
        'resolution': row.resolution.name,
        'meal_ref': row.mealId == null
            ? null
            : 'm${mealIds.indexOf(row.mealId!) + 1}',
      });
    }
    return DayDmlDocument(text: output.toString(), evidenceIds: ids);
  }
}

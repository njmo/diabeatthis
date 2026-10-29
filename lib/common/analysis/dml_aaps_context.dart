import '../../core/domain/model/aaps_prediction_snapshot.dart';
import '../../core/domain/model/bolus_wizard.dart';
import '../../core/domain/model/device_status.dart';
import '../../core/domain/model/treatment_base.dart';
import 'dml_time_blocks.dart';
import 'dml_timestamp.dart';

num? _finite(num? value) => value != null && value.isFinite ? value : null;
num? _positive(num? value) =>
    value != null && value.isFinite && value > 0 ? value : null;

AapsPredictionSnapshot? _prediction(DeviceStatus status, DateTime cutoff) {
  if (status.date.isAfter(cutoff)) return null;
  final prediction = AapsPredictionSnapshot.decode(status.aapsPredictionsJson);
  return prediction == null || prediction.calculatedAt.isAfter(cutoff)
      ? null
      : prediction;
}

/// Keep checkpoints, both extrema and the last point, without inventing values.
Map<String, Object?> _predictionFacts(AapsPredictionSnapshot prediction) => {
  'calculated_at': dmlTimestamp(prediction.calculatedAt),
  'point_columns': ['offset_min', 'predicted_mg_dl'],
  'source_step_min': 5,
  'sampling': 'checkpoints_extrema_and_last',
  'series': {
    for (final entry in prediction.series.entries)
      entry.key: _sample(entry.value),
  },
};

List<List<num>> _sample(List<double> values) {
  var minimum = 0;
  var maximum = 0;
  for (var i = 1; i < values.length; i++) {
    if (values[i] < values[minimum]) minimum = i;
    if (values[i] > values[maximum]) maximum = i;
  }
  final indexes = {
    0,
    minimum,
    maximum,
    values.length - 1,
    for (final index in [1, 3, 6, 12, 18, 24, 36, 47])
      if (index < values.length) index,
  }.toList()..sort();
  return [
    for (final index in indexes) [index * 5, values[index]],
  ];
}

/// These are recorded estimates/settings at this instant, not a full AAPS profile.
Map<String, Object?>? dmlAapsSnapshot(
  DeviceStatus? status, {
  required DateTime cutoff,
  bool includePrediction = true,
  String Function(Map<String, Object?>)? registerPrediction,
}) {
  if (status == null || status.date.isAfter(cutoff)) return null;
  final prediction = _prediction(status, cutoff);
  return {
    'observed_at': dmlTimestamp(status.date),
    'stored_sensitivity_ratio': _positive(status.sensitivityRatio),
    'isf_for_carbs_mg_dl_u': _positive(status.isfMgdlForCarbs),
    'prediction_age_min': prediction == null
        ? null
        : cutoff.difference(prediction.calculatedAt).inSeconds / 60,
    if (includePrediction)
      if (registerPrediction == null)
        'prediction': prediction == null ? null : _predictionFacts(prediction)
      else
        'prediction_ref': prediction == null
            ? null
            : registerPrediction(_predictionFacts(prediction)),
  };
}

/// Pure export from existing history. No preference, network or dose calculation.
Map<String, Object?> dmlAapsContext({
  required List<DeviceStatus>? statuses,
  required List<Treatment>? treatments,
  required DateTime start,
  required DateTime end,
  Iterable<DeviceStatus> predictionAnchors = const [],
  String Function(Map<String, Object?>)? registerPrediction,
}) {
  bool within(DateTime at) => !at.isBefore(start) && !at.isAfter(end);
  final ordered = statuses?.where((s) => within(s.date)).toList()
    ?..sort((a, b) => a.date.compareTo(b.date));
  // Hour buckets use instants, so repeated local hours across DST stay distinct.
  final hourly = <int, DeviceStatus>{};
  for (final status in ordered ?? <DeviceStatus>[]) {
    if (_prediction(status, end) != null) {
      hourly[status.date.toUtc().millisecondsSinceEpoch ~/
              Duration.millisecondsPerHour] =
          status;
    }
  }
  final forecasts =
      <DateTime, ({DeviceStatus status, AapsPredictionSnapshot prediction})>{};
  for (final status in [...hourly.values, ...predictionAnchors]) {
    if (!within(status.date)) continue;
    final prediction = _prediction(status, end);
    if (prediction == null) continue;
    final key = prediction.calculatedAt.toUtc();
    final previous = forecasts[key];
    if (previous == null || !status.date.isBefore(previous.status.date)) {
      forecasts[key] = (status: status, prediction: prediction);
    }
  }
  return {
    'start': dmlTimestamp(start),
    'end': dmlTimestamp(end),
    'notes': [
      'AAPS forecasts are model predictions, not observed CGM or measured absorption.',
      'Sensitivity ratio can be a legacy default of 1; it is not proof of an observed sensitivity change.',
      'Calculator IC, ISF, targets and percentages describe that calculation, not a full profile or confirmed insulin delivery.',
      'Calculator glucose-related values keep recorded_units. Missing units prohibit interpreting or comparing those raw values.',
    ],
    'parameter_columns': [
      'time',
      'stored_sensitivity_ratio',
      'isf_for_carbs_mg_dl_u',
    ],
    'parameter_blocks': dmlTimeBlocks(
      ordered == null
          ? null
          : [
              for (final status in ordered)
                (
                  at: status.date,
                  values: [
                    _positive(status.sensitivityRatio),
                    _positive(status.isfMgdlForCarbs),
                  ],
                ),
            ],
    ),
    'prediction_sampling': 'latest_valid_per_elapsed_hour_plus_meal_boundaries',
    'prediction_columns': [
      'calculated_at',
      'status_observed_at',
      registerPrediction == null ? 'sampled_prediction' : 'prediction_ref',
    ],
    'prediction_blocks': dmlTimeBlocks(
      statuses == null && forecasts.isEmpty
          ? null
          : [
              for (final entry in forecasts.values)
                (
                  at: entry.prediction.calculatedAt,
                  values: [
                    entry.status.date,
                    registerPrediction == null
                        ? _predictionFacts(entry.prediction)
                        : registerPrediction(
                            _predictionFacts(entry.prediction),
                          ),
                  ],
                ),
            ],
    ),
    'calculator_columns': [
      'time',
      'calculated_at',
      'recorded_units',
      'ic_g_u',
      'isf_raw',
      'target_low_raw',
      'target_high_raw',
      'percentage',
      'profile_name',
      'calculated_total_u',
      'carbs_component_u',
      'glucose_component_u',
      'cob_component_u',
      'trend_component_u',
      'bolus_iob_used',
      'basal_iob_used',
      'cob_used',
      'glucose_used',
      'trend_used',
      'temp_target_used',
      'superbolus_used',
      'carbs_used',
    ],
    'calculator_blocks': dmlTimeBlocks(
      treatments
          ?.whereType<BolusWizard>()
          .map((wizard) => _calculatorRow(wizard, start, end))
          .whereType<DmlTimedRow>(),
    ),
  };
}

DmlTimedRow? _calculatorRow(BolusWizard wizard, DateTime start, DateTime end) {
  final calculator = wizard.calculatorResult;
  if (!wizard.isValid ||
      calculator == null ||
      wizard.createdAt.isBefore(start) ||
      wizard.createdAt.isAfter(end)) {
    return null;
  }
  final calculatedAt = calculator.timestamp ?? calculator.dateCreated;
  if (calculatedAt?.isAfter(end) == true) return null;
  var low = _positive(calculator.targetBGLow);
  var high = _positive(calculator.targetBGHigh);
  if (low != null && high != null && high < low) {
    low = null;
    high = null;
  }
  return (
    at: wizard.createdAt,
    values: [
      calculatedAt,
      wizard.units,
      _positive(calculator.ic),
      _positive(calculator.isf),
      low,
      high,
      calculator.percentageCorrection != null &&
              calculator.percentageCorrection! >= 0
          ? calculator.percentageCorrection
          : null,
      calculator.profileName,
      _finite(calculator.totalInsulin),
      _finite(calculator.carbsInsulin),
      _finite(calculator.glucoseInsulin),
      _finite(calculator.cobInsulin),
      _finite(calculator.trendInsulin),
      calculator.wasBolusIOBUsed,
      calculator.wasBasalIOBUsed,
      calculator.wasCOBUsed,
      calculator.wasGlucoseUsed,
      calculator.wasTrendUsed,
      calculator.wasTempTargetUsed,
      calculator.wasSuperbolusUsed,
      calculator.wereCarbsUsed,
    ],
  );
}

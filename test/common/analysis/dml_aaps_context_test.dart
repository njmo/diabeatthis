import 'dart:convert';

import 'package:diabeatthis/common/analysis/dml_aaps_context.dart';
import 'package:diabeatthis/core/data_sources/nightscout/helpers/treatments_factory.dart';
import 'package:diabeatthis/core/domain/model/bolus_wizard.dart';
import 'package:diabeatthis/core/domain/model/device_status.dart';
import 'package:diabeatthis/core/domain/model/treatment_base.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/device_status_factory.dart';

final start = DateTime.utc(2026, 10, 25);
DeviceStatus predicted(
  DateTime at, {
  DateTime? calculatedAt,
  List<double>? curve,
}) =>
    testDeviceStatus(
      date: at,
      iob: 1,
      cob: 10,
      tick: '0',
      bg: 120,
      sensitivityRatio: 1.2,
      isfMgdlForCarbs: 45,
    ).copyWith(
      aapsPredictionsJson: jsonEncode({
        'timestamp': (calculatedAt ?? at).toIso8601String(),
        'predBGs': {
          'IOB': curve ?? [120, 125, 130, 135],
        },
      }),
    );
List<List<dynamic>> rows(Map<String, Object?> section, String key) =>
    (section[key] as List)
        .expand((block) => (block as Map)['rows'] as List)
        .map((row) => row as List<dynamic>)
        .toList();
List<Treatment> calculatorRecords(
  DateTime at, {
  String? units = 'mmol/l',
  bool valid = true,
  DateTime? calculatedAt,
}) => TreatmentFactory().parseTreatments([
  {
    '_id': 'not-for-export',
    'eventType': 'Bolus Wizard',
    'created_at': at.toIso8601String(),
    'glucose': 120,
    'units': units,
    'isValid': valid,
    'bolusCalculatorResult': {
      'ic': 12,
      'isf': 4,
      'targetBGLow': 5.5,
      'targetBGHigh': 6,
      'percentageCorrection': 0,
      'profileName': 'Profile A',
      'totalInsulin': 0,
      'glucoseInsulin': -0.4,
      'wasGlucoseUsed': false,
      'wasCOBUsed': true,
      if (calculatedAt != null)
        'timestamp': calculatedAt.millisecondsSinceEpoch,
    },
  },
]);

void main() {
  test(
    'forecasts retain checkpoints, exact extrema and last point without interpolation',
    () {
      final curve = [for (var i = 0; i < 48; i++) 120.0 + i];
      curve[2] = 50;
      curve[20] = 300;
      final snapshot = dmlAapsSnapshot(
        predicted(start, curve: curve),
        cutoff: start,
      )!;
      final prediction = snapshot['prediction'] as Map;
      final points = (prediction['series'] as Map)['IOB'] as List;
      expect(
        points,
        containsAll([
          [0, 120.0],
          [10, 50.0],
          [100, 300.0],
          [235, 167.0],
        ]),
      );
      expect(points.length, lessThanOrEqualTo(12));
      for (final point in points) {
        expect(point[1], curve[(point[0] as int) ~/ 5]);
      }
      expect(snapshot['stored_sensitivity_ratio'], 1.2);
      expect(snapshot['isf_for_carbs_mg_dl_u'], 45);
    },
  );
  test('future or malformed forecasts never become pre-meal evidence', () {
    expect(
      dmlAapsSnapshot(
        predicted(start.add(const Duration(minutes: 1))),
        cutoff: start,
      ),
      isNull,
    );
    final future = predicted(
      start,
      calculatedAt: start.add(const Duration(minutes: 1)),
    );
    expect(dmlAapsSnapshot(future, cutoff: start)!['prediction'], isNull);
    expect(
      dmlAapsSnapshot(
        predicted(start).copyWith(aapsPredictionsJson: '{'),
        cutoff: start,
      )!['prediction'],
      isNull,
    );
  });
  test(
    'forecast timeline is bounded by hour while preserving meal-boundary snapshots',
    () {
      final early = predicted(start.add(const Duration(minutes: 2)));
      final middle = predicted(start.add(const Duration(minutes: 30)));
      final latest = predicted(start.add(const Duration(minutes: 55)));
      final next = predicted(start.add(const Duration(hours: 1, minutes: 10)));
      final section = dmlAapsContext(
        statuses: [next, middle, early, latest],
        treatments: [],
        start: start,
        end: start.add(const Duration(hours: 2)),
        predictionAnchors: [early],
      );
      final predictions = rows(section, 'prediction_blocks');
      expect(predictions, hasLength(3));
      expect(
        predictions.map(
          (r) => DateTime.parse((r[2] as Map)['calculated_at'] as String),
        ),
        [early.date, latest.date, next.date],
      );
      expect(rows(section, 'parameter_blocks'), hasLength(4));
    },
  );
  test(
    'calculator keeps raw units, zero percent and signed components without delivery claims',
    () {
      final section = dmlAapsContext(
        statuses: [],
        treatments: calculatorRecords(start),
        start: start,
        end: start.add(const Duration(minutes: 1)),
      );
      final columns = (section['calculator_columns'] as List).cast<String>();
      final row = rows(section, 'calculator_blocks').single;
      final fields = Map.fromIterables(columns, row);
      expect(fields['recorded_units'], 'mmol/l');
      expect(fields['isf_raw'], 4);
      expect(fields['target_low_raw'], 5.5);
      expect(fields['percentage'], 0);
      expect(fields['calculated_total_u'], 0);
      expect(fields['glucose_component_u'], -0.4);
      expect(fields['glucose_used'], false);
      expect(fields['cob_used'], true);
      expect(jsonEncode(section), isNot(contains('not-for-export')));
    },
  );
  test(
    'missing units stay unknown and invalid or out-of-window calculations are excluded',
    () {
      final section = dmlAapsContext(
        statuses: [],
        treatments: [
          ...calculatorRecords(start, units: null),
          ...calculatorRecords(
            start.add(const Duration(minutes: 1)),
            valid: false,
          ),
          ...calculatorRecords(start.subtract(const Duration(minutes: 1))),
          ...calculatorRecords(
            start,
            calculatedAt: start.add(const Duration(hours: 1)),
          ),
        ],
        start: start,
        end: start.add(const Duration(minutes: 10)),
      );
      final row = rows(section, 'calculator_blocks').single;
      expect(row[2], isNull);
    },
  );
  test('unknown sources remain null, observed empty sources remain empty', () {
    final unknown = dmlAapsContext(
      statuses: null,
      treatments: null,
      start: start,
      end: start,
    );
    final empty = dmlAapsContext(
      statuses: [],
      treatments: [],
      start: start,
      end: start,
    );
    for (final key in [
      'parameter_blocks',
      'prediction_blocks',
      'calculator_blocks',
    ]) {
      expect(unknown[key], isNull);
      expect(empty[key], isEmpty);
    }
    final legacy = dmlAapsSnapshot(
      testDeviceStatus(date: start, iob: 0, cob: 0, tick: '0', bg: 120),
      cutoff: start,
    )!;
    expect(legacy['isf_for_carbs_mg_dl_u'], isNull);
  });
  test(
    'invalid numeric settings remain unknown instead of inventing a valid target range',
    () {
      final wizard = calculatorRecords(start).whereType<BolusWizard>().single;
      final invalid = wizard.copyWith(
        calculatorResult: wizard.calculatorResult!.copyWith(
          targetBGLow: 8,
          targetBGHigh: 6,
          isf: double.nan,
          percentageCorrection: -1,
        ),
      );
      final section = dmlAapsContext(
        statuses: [predicted(start).copyWith(isfMgdlForCarbs: double.infinity)],
        treatments: [invalid],
        start: start,
        end: start,
      );
      final fields = Map.fromIterables(
        section['calculator_columns'] as List,
        rows(section, 'calculator_blocks').single,
      );
      expect(fields['isf_raw'], isNull);
      expect(fields['target_low_raw'], isNull);
      expect(fields['target_high_raw'], isNull);
      expect(fields['percentage'], isNull);
      expect(rows(section, 'parameter_blocks').single.last, isNull);
    },
  );
}

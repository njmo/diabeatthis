import 'package:diabeatthis/common/history/insulin_bolus_summary.dart';
import 'package:diabeatthis/core/domain/model/correction_bolus.dart';
import 'package:diabeatthis/core/domain/model/manual_bolus.dart';
import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026, 9, 8, 12);
  final end = start.add(const Duration(hours: 3));

  test('counts manual corrections separately and preserves small doses', () {
    final summary = InsulinBolusSummary.fromTreatments(
      start: start,
      end: end,
      treatments: [
        ManualBolus(externalId: 'manual', createdAt: start, insulin: 0.25),
        CorrectionBolus(externalId: 'first', createdAt: start, insulin: 0.05),
        CorrectionBolus(externalId: 'last', createdAt: end, insulin: 0.05),
      ],
    );
    expect(summary.manualCount, 1);
    expect(summary.otherCount, 2);
    expect(summary.count, 3);
    expect(summary.units, closeTo(0.35, 0.000001));
  });

  test('excludes premeal, invalid, nonpositive and unrelated records', () {
    final summary = InsulinBolusSummary.fromTreatments(
      start: start,
      end: end,
      treatments: [
        ManualBolus(
          externalId: 'before',
          createdAt: start.subtract(const Duration(seconds: 1)),
          insulin: 2,
        ),
        CorrectionBolus(
          externalId: 'after',
          createdAt: end.add(const Duration(seconds: 1)),
          insulin: 2,
        ),
        ManualBolus(
          externalId: 'invalid',
          createdAt: start,
          insulin: 2,
          isValid: false,
        ),
        CorrectionBolus(externalId: 'zero', createdAt: start, insulin: 0),
        ManualBolus(externalId: 'negative', createdAt: start, insulin: -1),
        ManualBolus(externalId: 'nan', createdAt: start, insulin: double.nan),
        Treat(externalId: 'carbs', createdAt: start, carbs: 10),
      ],
    );
    expect(summary.count, 0);
    expect(summary.units, 0);
  });
}

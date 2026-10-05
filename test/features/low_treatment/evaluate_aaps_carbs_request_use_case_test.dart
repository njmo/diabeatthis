import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/features/low_treatment/domain/models/aaps_carbs_request_signal.dart';
import 'package:diabeatthis/features/low_treatment/domain/use_cases/evaluate_aaps_carbs_request_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/device_status_factory.dart';

void main() {
  final now = DateTime(2026, 9, 15, 12);
  final glucose = Glucose(
    externalId: null,
    source: GlucoseSource.cloud,
    date: now.subtract(const Duration(minutes: 2)),
    sgv: 100,
    direction: 'Flat',
  );
  const evaluate = EvaluateAapsCarbsRequestUseCase();

  test('accepts a fresh positive request with fresh CGM', () {
    final status = testDeviceStatus(
      date: now.subtract(const Duration(minutes: 3)),
      iob: 0,
      cob: 0,
      tick: '0',
      bg: 100,
      carbsReq: 8,
    );

    expect(
      evaluate(status: status, glucose: [glucose], now: now).type,
      AapsCarbsRequestSignalType.positive,
    );
  });

  test('rejects future and ten-minute-old status or CGM', () {
    final base = testDeviceStatus(
      date: now,
      iob: 0,
      cob: 0,
      tick: '0',
      bg: 100,
      carbsReq: 8,
    );
    final oldGlucose = glucose.copyWith(
      date: now.subtract(EvaluateAapsCarbsRequestUseCase.maximumAge),
    );

    expect(
      evaluate(
        status: base.copyWith(date: now.add(const Duration(seconds: 1))),
        glucose: [glucose],
        now: now,
      ).type,
      AapsCarbsRequestSignalType.unavailable,
    );
    expect(
      evaluate(
        status: base.copyWith(
          date: now.subtract(EvaluateAapsCarbsRequestUseCase.maximumAge),
        ),
        glucose: [glucose],
        now: now,
      ).type,
      AapsCarbsRequestSignalType.unavailable,
    );
    expect(
      evaluate(status: base, glucose: [oldGlucose], now: now).type,
      AapsCarbsRequestSignalType.unavailable,
    );
  });

  test('only an explicit finite zero withdraws a request', () {
    final base = testDeviceStatus(
      date: now,
      iob: 0,
      cob: 0,
      tick: '0',
      bg: 100,
    );

    expect(
      evaluate(status: base, glucose: const [], now: now).type,
      AapsCarbsRequestSignalType.withdrawn,
    );
    for (final status in [
      base.copyWith(hasCarbsReq: false),
      base.copyWith(carbsReq: -1),
      base.copyWith(carbsReq: double.nan),
    ]) {
      expect(
        evaluate(status: status, glucose: [glucose], now: now).type,
        AapsCarbsRequestSignalType.unavailable,
      );
    }
  });

  test('prefers suggestion timestamp over a newer envelope timestamp', () {
    final status = testDeviceStatus(
      date: now,
      iob: 0,
      cob: 0,
      tick: '0',
      bg: 100,
      carbsReq: 8,
    ).copyWith(suggestedAt: now.subtract(const Duration(minutes: 11)));

    expect(
      evaluate(status: status, glucose: [glucose], now: now).type,
      AapsCarbsRequestSignalType.unavailable,
    );
  });
}

import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/features/caregiver/data/caregiver_nightscout_snapshot.dart';
import 'package:diabeatthis/features/dashboard/data/providers/blood_sugar_readings_list_provider.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/mini_glucose_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/device_status_factory.dart';
import '../../helpers/localized_material_app.dart';

class ForbiddenPatientReadings extends BloodSugarReadingsListNotifier {
  @override
  AsyncValue<List<Glucose>> build() =>
      throw StateError('Caregiver chart must not read the patient cache');
}

void main() {
  test(
    'CGM value and time are independent of an older/zero pump suggested glucose',
    () {
      final now = DateTime.now();
      final glucose = Glucose(
        externalId: 'g',
        source: GlucoseSource.cloud,
        date: now,
        sgv: 123,
        direction: 'Flat',
      );
      final device = testDeviceStatus(
        date: now.subtract(const Duration(minutes: 10)),
        iob: 1,
        cob: 2,
        tick: '0',
        bg: 0,
      );
      final snapshot = CaregiverNightscoutSnapshot(
        glucose: [
          glucose.copyWith(
            sgv: 180,
            date: now.subtract(const Duration(minutes: 5)),
          ),
          glucose,
          glucose.copyWith(sgv: 0),
          glucose.copyWith(type: GlucoseType.finger, sgv: 300),
        ],
        deviceStatus: device,
        targetFetched: true,
        hasFailures: false,
      );
      expect(snapshot.latestGlucose!.sgv, 123);
      expect(snapshot.latestGlucose!.date, now);
      expect(snapshot.readings.map((reading) => reading.sgv), [123, 180]);
    },
  );
  testWidgets(
    'provided caregiver chart data never reads patient cached readings, including empty data',
    (tester) async {
      final now = DateTime.now();
      final readings = [
        for (var i = 0; i < 3; i++)
          Glucose(
            externalId: '$i',
            source: GlucoseSource.cloud,
            date: now.subtract(Duration(minutes: i * 5)),
            sgv: 100 + i,
            direction: 'Flat',
          ),
      ];
      Widget view(List<Glucose> data) => ProviderScope(
        overrides: [
          bloodSugarReadingsListProvider.overrideWith(
            ForbiddenPatientReadings.new,
          ),
        ],
        child: localizedMaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 100,
              child: MiniGlucoseChart(readings: data),
            ),
          ),
        ),
      );
      await tester.pumpWidget(view(readings));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(view([]));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}

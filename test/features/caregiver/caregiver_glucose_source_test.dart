import 'package:clock/clock.dart';
import 'package:diabeatthis/core/data_sources/nightscout/repository/nightscout_repository_impl.dart';
import 'package:diabeatthis/core/data_sources/nightscout/services/nightscout_service.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/features/caregiver/data/caregiver_nightscout_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

class MixedEntriesService extends NightscoutService {
  MixedEntriesService() : super(nightscoutUrl: 'https://example.test');
  Uri? request;
  @override
  Future<dynamic> fetchNightscoutData(Uri url) async {
    request = url;
    return [
      {'_id': 'manual', 'type': 'mbg', 'sgv': 250},
      {'_id': 'calibration', 'type': 'cal'},
      {
        '_id': 'sensor',
        'type': 'sgv',
        'sgv': 123,
        'direction': 'Flat',
        'created_at': '2026-11-06T10:00:00Z',
        'date': 1793959200000,
      },
    ];
  }
}

void main() {
  test(
    'realistic mixed entries exclude manual and calibration before parsing',
    () async {
      final service = MixedEntriesService();
      final repository = NightscoutRepositoryImpl(
        nightscoutUrl: 'https://example.test',
        service: service,
      );
      final readings = await repository.fetchLastGlucoseWithLimit(10);
      expect(readings.single.sgv, 123);
      expect(service.request!.queryParameters['count'], '10');
      expect(
        service.request!.queryParameters.containsKey('find[type]'),
        isFalse,
      );
    },
  );
  test(
    'future samples beyond two minute clock tolerance cannot hide current CGM',
    () {
      final now = DateTime.utc(2026, 11, 6, 10);
      withClock(Clock.fixed(now), () {
        final current = Glucose(
          externalId: 'current',
          source: GlucoseSource.cloud,
          date: now,
          sgv: 123,
          direction: 'Flat',
        );
        final snapshot = CaregiverNightscoutSnapshot(
          glucose: [
            current.copyWith(date: now.add(const Duration(hours: 1)), sgv: 300),
            current,
          ],
          targetFetched: false,
          hasFailures: false,
        );
        expect(snapshot.latestGlucose!.sgv, 123);
        expect(snapshot.readings.length, 1);
      });
    },
  );
}

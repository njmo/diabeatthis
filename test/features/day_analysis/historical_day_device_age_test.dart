import 'package:clock/clock.dart';
import 'package:diabeatthis/core/data_sources/nightscout/repository/nightscout_repository_impl.dart';
import 'package:diabeatthis/core/data_sources/nightscout/services/nightscout_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'historical device ages query only changes strictly before the cutoff',
    () async {
      final cutoff = DateTime.utc(2026, 9, 10);
      final service = HistoricalChangeService();
      final repository = NightscoutRepositoryImpl(
        nightscoutUrl: 'https://example.com',
        service: service,
      );
      for (final type in ['Sensor Change', 'Insulin Change']) {
        final age = await withClock(
          Clock.fixed(cutoff),
          () => type == 'Sensor Change'
              ? repository.getLatestSensorChangeAge()
              : repository.getLatestInsulinChangeAge(),
        );
        expect(age, const Duration(days: 2));
        final query = service.requests.last.queryParameters;
        expect(query['find[created_at][\$lt]'], cutoff.toIso8601String());
        expect(query['find[eventType]'], type);
        expect(query['count'], '1');
      }
    },
  );
}

class HistoricalChangeService extends NightscoutService {
  HistoricalChangeService() : super(nightscoutUrl: '');
  final requests = <Uri>[];
  @override
  Future<dynamic> fetchNightscoutData(Uri url) async {
    requests.add(url);
    return [
      {'created_at': '2026-09-08T00:00:00.000Z'},
    ];
  }
}

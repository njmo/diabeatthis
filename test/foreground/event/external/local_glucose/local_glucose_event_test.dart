import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/foreground/event/external/external_event.dart';
import 'package:diabeatthis/foreground/event/external/local_glucose/local_glucose_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocalGlucoseEvent', () {
    test('maps receiver payload to glucose reading', () {
      final timestamp = DateTime(2026, 5, 18, 12, 30).millisecondsSinceEpoch;

      final event = LocalGlucoseEvent.fromJson({
        'externalId': 'xdrip-$timestamp',
        'source': 'xdrip',
        'timestamp': timestamp,
        'sgv': 143,
        'direction': 'FortyFiveUp',
      });

      expect(event.data.externalId, 'xdrip-$timestamp');
      expect(event.data.source, GlucoseSource.xdrip);
      expect(event.data.date, DateTime.fromMillisecondsSinceEpoch(timestamp));
      expect(event.data.sgv, 143);
      expect(event.data.direction, 'FortyFiveUp');
    });

    test('parses external event wrapper', () {
      final timestamp = DateTime(2026, 5, 18, 12, 30).millisecondsSinceEpoch;

      final event = ExternalEvent.fromJson({
        'external_event': 'local_glucose',
        'data': {
          'externalId': 'xdrip-$timestamp',
          'source': 'xdrip',
          'timestamp': timestamp,
          'sgv': 143,
          'direction': 'FortyFiveUp',
        },
      });

      expect(event, isA<ExternalEvent>());
      event.when(
        appEvent: (_) => fail('Expected local glucose event'),
        notificationEvent: (_) => fail('Expected local glucose event'),
        localGlucose: (data) {
          expect(data.data.source, GlucoseSource.xdrip);
          expect(data.data.sgv, 143);
        },
      );
    });
  });
}

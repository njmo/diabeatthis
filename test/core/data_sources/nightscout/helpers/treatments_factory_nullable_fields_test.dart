import 'package:diabeatthis/core/data_sources/nightscout/helpers/treatments_factory.dart';
import 'package:diabeatthis/core/domain/model/extended_carb.dart';
import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'nullable optional Nightscout fields do not turn basal into extended carbs',
    () {
      final records = TreatmentFactory().parseTreatments([
        {
          'eventType': 'Temp Basal',
          'created_at': '2026-05-06T10:00:00Z',
          'carbs': null,
          'duration': 4,
          'rate': 0.5,
        },
        {
          'eventType': 'Carb Correction',
          'created_at': '2026-05-06T10:01:00Z',
          'carbs': 10,
          'duration': null,
        },
        {
          'eventType': 'Carb Correction',
          'created_at': '2026-05-06T10:02:00Z',
          'carbs': 20,
          'duration': 120,
        },
      ]);
      expect(records, hasLength(2));
      expect(records[0], isA<Treat>());
      expect((records[0] as Treat).carbs, 10);
      expect(records[1], isA<ExtendedCarb>());
      expect((records[1] as ExtendedCarb).carbs, 20);
    },
  );
}

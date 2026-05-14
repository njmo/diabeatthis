import 'package:diabeatthis/core/data_sources/nightscout/dto/glucose_dto.dart';
import 'package:diabeatthis/core/data_sources/nightscout/mappers/glucose_mapper.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GlucoseMapper', () {
    test('maps Nightscout id and created timestamp', () {
      final dto = GlucoseDto.fromJson({
        '_id': 'sgv-1',
        'created_at': '2026-05-14T13:01:00.320Z',
        'sgv': 108,
        'direction': 'FortyFiveDown',
      });

      final glucose = dto.toDomain();

      expect(glucose.externalId, 'sgv-1');
      expect(glucose.source, GlucoseSource.cloud);
      expect(
        glucose.date.millisecondsSinceEpoch,
        DateTime.parse('2026-05-14T13:01:00.320Z').millisecondsSinceEpoch,
      );
      expect(glucose.sgv, 108);
      expect(glucose.direction, 'FortyFiveDown');
    });
  });
}

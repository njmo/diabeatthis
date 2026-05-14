import 'package:diabeatthis/core/data_sources/nightscout/dto/correction_bolus_dto.dart';
import 'package:diabeatthis/core/data_sources/nightscout/dto/extended_carb_dto.dart';
import 'package:diabeatthis/core/data_sources/nightscout/dto/manual_bolus_dto.dart';
import 'package:diabeatthis/core/data_sources/nightscout/dto/treat_dto.dart';
import 'package:diabeatthis/core/data_sources/nightscout/mappers/correction_bolus_mapper.dart';
import 'package:diabeatthis/core/data_sources/nightscout/mappers/extended_carb_mapper.dart';
import 'package:diabeatthis/core/data_sources/nightscout/mappers/manual_bolus_mapper.dart';
import 'package:diabeatthis/core/data_sources/nightscout/mappers/treat_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Nightscout treatment mappers', () {
    test('maps external ids from Nightscout ids', () {
      final correctionBolus = const CorrectionBolusDto(
        id: 'correction-1',
        createdAt: '2026-05-14T08:07:23.461Z',
        insulin: 0.3,
      ).toDomain();
      final manualBolus = const ManualBolusDto(
        id: 'manual-1',
        createdAt: '2026-05-14T08:08:23.461Z',
        insulin: 0.7,
      ).toDomain();
      final treat = const TreatDto(
        id: 'treat-1',
        createdAt: '2026-05-14T08:09:23.461Z',
        carbs: 12,
      ).toDomain();
      final extendedCarb = const ExtendedCarbDto(
        id: 'extended-carb-1',
        createdAt: '2026-05-14T08:10:23.461Z',
        carbs: 18,
        duration: 7200000,
      ).toDomain();

      expect(correctionBolus.externalId, 'correction-1');
      expect(manualBolus.externalId, 'manual-1');
      expect(treat.externalId, 'treat-1');
      expect(extendedCarb.externalId, 'extended-carb-1');
    });
  });
}

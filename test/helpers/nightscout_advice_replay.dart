import 'package:diabeatthis/core/data_sources/domain/glucose_history_repository.dart';
import 'package:diabeatthis/core/data_sources/nightscout/dto/device_status_dto.dart';
import 'package:diabeatthis/core/data_sources/nightscout/mappers/device_status_mapper.dart';
import 'package:diabeatthis/core/domain/model/device_status.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';

/// Minimal de-identified snapshot from the user-authorized Nightscout review.
/// Absolute times, IDs, notes and device metadata are deliberately omitted.
class NightscoutAdviceReplay implements GlucoseHistoryRepository {
  final DateTime reference;
  late List<Glucose> readings = [
    for (final sample in [(-778467, 181), (-479340, 172), (-178258, 158)])
      Glucose(
        externalId: null,
        source: GlucoseSource.cloud,
        date: reference.add(Duration(milliseconds: sample.$1)),
        sgv: sample.$2,
        direction: 'Flat',
      ),
  ];
  NightscoutAdviceReplay(this.reference);

  DeviceStatus get status => DeviceStatusDto(
    createdAt: reference
        .subtract(const Duration(milliseconds: 138398))
        .toIso8601String(),
    openaps: {
      'iob': {'iob': 1.149},
      'suggested': {'bg': 158, 'tick': '-14', 'COB': 26.576666666666668},
    },
  ).toDomain();

  @override
  Future<List<Glucose>> fetchGlucoseBetween(
    DateTime start,
    DateTime end,
  ) async => readings
      .where((r) => !r.date.isBefore(start) && !r.date.isAfter(end))
      .toList();

  @override
  Future<List<Glucose>> fetchRecentGlucose(int limit) async =>
      (readings.toList()..sort((a, b) => b.date.compareTo(a.date)))
          .take(limit)
          .toList();
}

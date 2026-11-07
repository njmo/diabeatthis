import 'package:diabeatthis/core/data_sources/nightscout/repository/nightscout_repository.dart';
import 'package:diabeatthis/core/domain/model/device_status.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/core/domain/model/treatment_base.dart';

class StatisticsNightscout extends FakeNightscoutBase {
  StatisticsNightscout({this.empty = false});
  final bool empty;
  final glucoseWindows = <(DateTime, DateTime)>[];
  final treatmentWindows = <(DateTime, DateTime)>[];
  final deviceWindows = <(DateTime, DateTime)>[];

  @override
  Future<List<Glucose>> fetchGlucoseBetween(
    DateTime start,
    DateTime end,
  ) async {
    glucoseWindows.add((start, end));
    if (empty) return [];
    return [
      for (
        var time = start;
        !time.isAfter(end);
        time = time.add(const Duration(minutes: 5))
      )
        Glucose(
          externalId: '$time',
          source: GlucoseSource.cloud,
          date: time,
          sgv: 120,
          direction: 'Flat',
        ),
    ];
  }

  @override
  Future<List<Treatment>> fetchTreatmentsBetween(
    DateTime start,
    DateTime end,
  ) async {
    treatmentWindows.add((start, end));
    return [];
  }

  @override
  Future<List<DeviceStatus>> fetchDeviceStatusBetween(
    DateTime start,
    DateTime end,
  ) async {
    deviceWindows.add((start, end));
    return [];
  }

  @override
  Future<DeviceStatus?> fetchLastDeviceStatusBefore(DateTime before) async =>
      null;
}

class FakeNightscoutBase implements NightscoutRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected Nightscout call: ${invocation.memberName}');
}

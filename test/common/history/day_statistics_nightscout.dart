import 'package:clock/clock.dart';
import 'package:diabeatthis/core/domain/model/device_status.dart';
import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/core/domain/model/manual_bolus.dart';
import 'package:diabeatthis/core/domain/model/treatment_base.dart';

import 'nightscout_statistics_fixture.dart';

class DayStatisticsNightscout extends StatisticsNightscout {
  DayStatisticsNightscout(this.day, {super.empty = false});
  final DateTime day;
  bool failGlucose = false;
  bool failTreatments = false;
  bool failDevices = false;
  final sensorAsOf = <DateTime>[];
  final podAsOf = <DateTime>[];
  @override
  Future<List<Glucose>> fetchGlucoseBetween(
    DateTime start,
    DateTime end,
  ) async {
    if (failGlucose) throw StateError('private-token');
    return super.fetchGlucoseBetween(start, end);
  }

  @override
  Future<List<Treatment>> fetchTreatmentsBetween(
    DateTime start,
    DateTime end,
  ) async {
    if (failTreatments) throw StateError('private-token');
    await super.fetchTreatmentsBetween(start, end);
    if (empty) return [];
    return <Treatment>[
          ManualBolus(
            externalId: 'night',
            createdAt: DateTime(day.year, day.month, day.day - 1, 23, 15),
            insulin: 1,
          ),
          ManualBolus(
            externalId: 'day',
            createdAt: DateTime(day.year, day.month, day.day, 10),
            insulin: 2,
          ),
        ]
        .where(
          (entry) =>
              !entry.createdAt!.isBefore(start) &&
              !entry.createdAt!.isAfter(end),
        )
        .toList();
  }

  @override
  Future<List<DeviceStatus>> fetchDeviceStatusBetween(
    DateTime start,
    DateTime end,
  ) async {
    if (failDevices) throw StateError('private-token');
    return super.fetchDeviceStatusBetween(start, end);
  }

  @override
  Future<Duration?> getLatestSensorChangeAge() async {
    sensorAsOf.add(clock.now());
    return empty ? null : const Duration(days: 1, minutes: 30);
  }

  @override
  Future<Duration?> getLatestInsulinChangeAge() async {
    podAsOf.add(clock.now());
    return empty ? null : const Duration(hours: 12);
  }
}

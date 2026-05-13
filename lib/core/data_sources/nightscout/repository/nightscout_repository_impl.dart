import 'package:clock/clock.dart';

import '../../../domain/model/device_status.dart';
import '../../../domain/model/glucose.dart';
import '../../../domain/model/meal.dart';
import '../../../domain/model/temporary_target.dart';
import '../../../domain/model/treatment_base.dart';
import '../../../logger/logger.dart';
import '../dto/device_status_dto.dart';
import '../dto/glucose_dto.dart';
import '../dto/meal_dto.dart';
import '../dto/temporary_target_dto.dart';
import '../helpers/treatments_factory.dart';
import '../mappers/device_status_mapper.dart';
import '../mappers/glucose_mapper.dart';
import '../mappers/meal_mapper.dart';
import '../mappers/temporary_target_mapper.dart';
import '../services/nightscout_service.dart';
import 'nightscout_repository.dart';

class NightscoutRepositoryImpl with Logging implements NightscoutRepository {
  final String nightscoutUrl;
  final NightscoutService service;
  final TreatmentFactory treatmentFactory = TreatmentFactory();

  NightscoutRepositoryImpl({
    required this.nightscoutUrl,
    NightscoutService? service,
  }) : service = service ?? NightscoutService(nightscoutUrl: nightscoutUrl);

  Uri _buildUri(String path, Map<String, String> qp) {
    final uri = Uri.parse(nightscoutUrl);
    return Uri(
      scheme: uri.scheme.isEmpty ? 'https' : uri.scheme,
      host: uri.host.isEmpty ? uri.path : uri.host,
      port: uri.hasPort ? uri.port : null,
      path: '${uri.host.isEmpty ? '' : uri.path}$path',
      queryParameters: qp,
    );
  }

  ({DateTime startUtc, DateTime endUtc}) _dayRangeUtc(DateTime day) {
    final startUtc = DateTime.utc(day.year, day.month, day.day);
    final endUtc = DateTime.utc(day.year, day.month, day.day, 23, 59, 59, 999);
    return (startUtc: startUtc, endUtc: endUtc);
  }

  @override
  Future<List<Treatment>> fetchTreatmentsOnDay(DateTime day) async {
    final r = _dayRangeUtc(day);
    final qp = {
      'find[created_at][\$gte]': r.startUtc.toIso8601String(),
      'find[created_at][\$lt]': r.endUtc.toIso8601String(),
      'find[\$or][0][eventType]': 'Meal Bolus',
      'find[\$or][1][eventType]': 'Bolus Wizard',
      'find[\$or][2][eventType]': 'Correction Bolus',
      'find[\$or][3][eventType]': 'Carb Correction',
    };
    final url = _buildUri('/api/v1/treatments.json', qp);
    final data = await service.fetchNightscoutData(url);
    return treatmentFactory.parseTreatments(data);
  }

  @override
  Future<List<Meal>> fetchMealsOnDay(DateTime day) async {
    final r = _dayRangeUtc(day);
    final qp = {
      'find[created_at][\$gte]': r.startUtc.toIso8601String(),
      'find[created_at][\$lt]': r.endUtc.toIso8601String(),
      'find[eventType]': 'Bolus Wizard',
    };
    final url = _buildUri('/api/v1/treatments.json', qp);
    final data = await service.fetchNightscoutData(url);
    return (data as List).map((e) => MealDto.fromJson(e).toDomain()).toList();
  }

  @override
  Future<List<Meal>> fetchMealsAfter(DateTime after) async {
    final qp = {
      'find[created_at][\$gte]': after.toUtc().toIso8601String(),
      'find[eventType]': 'Bolus Wizard',
    };
    final url = _buildUri('/api/v1/treatments.json', qp);
    final data = await service.fetchNightscoutData(url);
    return (data as List).map((e) => MealDto.fromJson(e).toDomain()).toList();
  }

  @override
  Future<TemporaryTarget> fetchLastTemporaryTarget() async {
    final qp = {'find[eventType]': 'Temporary Target', 'count': '1'};
    final url = _buildUri('/api/v1/treatments.json', qp);
    final data = await service.fetchNightscoutData(url);
    final dto = TemporaryTargetDto.fromJson(data.first);
    return dto.toDomain();
  }

  @override
  Future<TemporaryTarget> fetchLastTemporaryTargetById(String id) async {
    final qp = {'find[_id]': id, 'count': '1'};
    final url = _buildUri('/api/v1/treatments.json', qp);
    final data = await service.fetchNightscoutData(url);
    final dto = TemporaryTargetDto.fromJson(data.first);
    return dto.toDomain();
  }

  @override
  Future<List<Treatment>> fetchTreatmentsAfter(DateTime after) async {
    final qp = {
      'find[created_at][\$gte]': after.toUtc().toIso8601String(),
      'find[\$or][0][eventType]': 'Meal Bolus',
      'find[\$or][1][eventType]': 'Bolus Wizard',
      'find[\$or][2][eventType]': 'Correction Bolus',
      'find[\$or][3][eventType]': 'Carb Correction',
      'find[\$or][4][eventType]': 'Temporary Target',
    };
    final url = _buildUri('/api/v1/treatments.json', qp);
    final data = await service.fetchNightscoutData(url);
    return treatmentFactory.parseTreatments(data);
  }

  @override
  Future<List<Treatment>> fetchTreatmentsBetween(
    DateTime start,
    DateTime end,
  ) async {
    final qp = {
      'find[created_at][\$gte]': start.toUtc().toIso8601String(),
      'find[created_at][\$lt]': end.toUtc().toIso8601String(),
      'find[\$or][0][eventType]': 'Meal Bolus',
      'find[\$or][1][eventType]': 'Bolus Wizard',
      'find[\$or][2][eventType]': 'Correction Bolus',
      'find[\$or][3][eventType]': 'Carb Correction',
      'find[\$or][4][eventType]': 'Temporary Target',
      'count': '1000',
    };
    final url = _buildUri('/api/v1/treatments.json', qp);
    final data = await service.fetchNightscoutData(url);
    final treatments = treatmentFactory.parseTreatments(data);
    treatments.sort((a, b) {
      final aDate = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aDate.compareTo(bDate);
    });
    return treatments;
  }

  @override
  Future<List<Glucose>> fetchGlucoseOnDay(DateTime day) async {
    final r = _dayRangeUtc(day);
    final qp = {
      'find[date][\$gte]': r.startUtc.millisecondsSinceEpoch.toString(),
      'find[date][\$lt]': r.endUtc.millisecondsSinceEpoch.toString(),
      'count': '288',
    };
    final url = _buildUri('/api/v1/entries.json', qp);
    final data = await service.fetchNightscoutData(url);

    return (data as List)
        .map((e) => GlucoseDto.fromJson(e).toDomain())
        .toList();
  }

  @override
  Future<List<Glucose>> fetchGlucoseBetween(
    DateTime start,
    DateTime end,
  ) async {
    final minutes = end.difference(start).inMinutes.abs();
    final count = (minutes / 5).ceil() + 24;
    final qp = {
      'find[date][\$gte]': start.millisecondsSinceEpoch.toString(),
      'find[date][\$lt]': end.millisecondsSinceEpoch.toString(),
      'count': count.clamp(48, 1000).toString(),
    };
    final url = _buildUri('/api/v1/entries.json', qp);
    final data = await service.fetchNightscoutData(url);

    final glucose = (data as List)
        .map((e) => GlucoseDto.fromJson(e).toDomain())
        .toList();
    glucose.sort((a, b) => a.date.compareTo(b.date));
    return glucose;
  }

  @override
  Future<List<Glucose>> fetchLastGlucoseWithLimit(int limit) async {
    final qp = {'count': limit.toStringAsFixed(0)};
    final url = _buildUri('/api/v1/entries.json', qp.cast<String, String>());
    final data = await service.fetchNightscoutData(url);

    return (data as List)
        .map((e) => GlucoseDto.fromJson(e).toDomain())
        .toList();
  }

  @override
  Future<List<Glucose>> fetchGlucoseAfter(DateTime after) async {
    final qp = {
      'find[date][\$gte]': after.millisecondsSinceEpoch.toString(),
      'count': '288',
    };
    final url = _buildUri('/api/v1/base.json', qp);
    final data = await service.fetchNightscoutData(url);

    return (data as List)
        .map((e) => GlucoseDto.fromJson(e).toDomain())
        .toList();
  }

  @override
  Future<DeviceStatus> fetchLastDeviceStatus() async {
    final qp = {'find[openaps.suggested][\$exists]': 'true', 'count': '1'};
    final url = _buildUri('/api/v1/devicestatus.json', qp);
    final data = await service.fetchNightscoutData(url);
    final dto = DeviceStatusDto.fromJson(data.first);
    return dto.toDomain();
  }

  @override
  Future<List<DeviceStatus>> fetchDeviceStatusBetween(
    DateTime start,
    DateTime end,
  ) async {
    final minutes = end.difference(start).inMinutes.abs();
    final qp = {
      'find[created_at][\$gte]': start.toUtc().toIso8601String(),
      'find[created_at][\$lt]': end.toUtc().toIso8601String(),
      'find[openaps.suggested][\$exists]': 'true',
      'count': (minutes + 24).clamp(48, 1000).toString(),
    };
    final url = _buildUri('/api/v1/devicestatus.json', qp);
    final data = await service.fetchNightscoutData(url);
    final statuses = (data as List)
        .map((e) => DeviceStatusDto.fromJson(e).toDomain())
        .toList();
    statuses.sort((a, b) => a.date.compareTo(b.date));
    return statuses;
  }

  @override
  Future<DeviceStatus?> fetchLastDeviceStatusBefore(DateTime before) async {
    final qp = {
      'find[created_at][\$lte]': before.toUtc().toIso8601String(),
      'find[openaps.suggested][\$exists]': 'true',
      'count': '1',
    };
    final url = _buildUri('/api/v1/devicestatus.json', qp);
    final data = await service.fetchNightscoutData(url) as List;
    if (data.isEmpty) return null;
    final dto = DeviceStatusDto.fromJson(data.first);
    return dto.toDomain();
  }

  @override
  Future<Duration?> getLatestSensorChangeAge() async {
    final qp = {
      'find[created_at][\$lt]': clock.now().toUtc().toIso8601String(),
      'find[eventType]': 'Sensor Change',
      'count': '1',
    };
    final url = _buildUri('/api/v1/treatments.json', qp);
    final list = await service.fetchNightscoutData(url) as List;
    if (list.isEmpty) return null;
    final created = DateTime.parse(list.first['created_at']).toUtc();
    return clock.now().toUtc().difference(created);
  }

  @override
  Future<Duration?> getLatestInsulinChangeAge() async {
    final qp = {
      'find[created_at][\$lt]': clock.now().toUtc().toIso8601String(),
      'find[eventType]': 'Insulin Change',
      'count': '1',
    };
    final url = _buildUri('/api/v1/treatments.json', qp);
    final list = await service.fetchNightscoutData(url) as List;
    if (list.isEmpty) return null;
    final created = DateTime.parse(list.first['created_at']).toUtc();
    return clock.now().toUtc().difference(created);
  }
}

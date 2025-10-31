//  Provides NightscoutRepository and related data such as sensor age, cannula age, and device status.

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../domain/model/device_status.dart';
import '../../domain/model/meal.dart';
import '../../domain/repository/nightscout_repository.dart';
import '../../nightscout/providers/nightscout_url_provider.dart';
import '../repository/nightscout_repository_impl.dart';

part 'nightscout_repository_provider.g.dart';

@riverpod
NightscoutRepository nightscoutRepository(Ref ref) {
  final url = ref.watch(nightscoutUrlProvider);
  return NightscoutRepositoryImpl(nightscoutUrl: url);
}

@riverpod
Future<Duration?> sensorAge(Ref ref) async {
  final repository = ref.watch(nightscoutRepositoryProvider);
  return await repository.getLatestSensorChangeAge();
}

@riverpod
Future<Duration?> canulaAge(Ref ref) async {
  final repository = ref.watch(nightscoutRepositoryProvider);
  return await repository.getLatestInsulinChangeAge();
}

@riverpod
Future<DeviceStatus> deviceStatus(Ref ref) async {
  final repository = ref.watch(nightscoutRepositoryProvider);
  return await repository.fetchLastDeviceStatus();
}

@riverpod
Future<List<Meal>> meals(Ref ref) async {
  final repository = ref.watch(nightscoutRepositoryProvider);
  return await repository.fetchMealsOnDay(DateTime.now());
}
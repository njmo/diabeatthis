//  Provides NightscoutRepository and related data such as sensor age, cannula age, and device status.

import 'package:clock/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../domain/model/bolus_wizard.dart';
import '../../../domain/model/device_status.dart';
import '../../../domain/model/glucose.dart';
import '../../../domain/model/temporary_target.dart';
import '../../../domain/model/treatment_base.dart';
import '../repository/nightscout_repository.dart';
import '../repository/nightscout_repository_impl.dart';
import 'nightscout_url_provider.dart';

part 'nightscout_repository_provider.g.dart';

@riverpod
Future<NightscoutRepository> nightscoutRepository(Ref ref) async {
  final url = await ref.watch(nightscoutUrlProvider.future);
  return NightscoutRepositoryImpl(nightscoutUrl: url!);
}

@riverpod
Future<Duration?> sensorAge(Ref ref) async {
  final repository = await ref.watch(nightscoutRepositoryProvider.future);
  return await repository.getLatestSensorChangeAge();
}

@riverpod
Future<Duration?> canulaAge(Ref ref) async {
  final repository = await ref.watch(nightscoutRepositoryProvider.future);
  return await repository.getLatestInsulinChangeAge();
}

@riverpod
Future<DeviceStatus> deviceStatus(Ref ref) async {
  final repository = await ref.watch(nightscoutRepositoryProvider.future);
  return await repository.fetchLastDeviceStatus();
}

@riverpod
Future<TemporaryTarget> temporaryTarget(Ref ref) async {
  final repository = await ref.watch(nightscoutRepositoryProvider.future);
  return await repository.fetchLastTemporaryTarget();
}

@riverpod
Future<TemporaryTarget> temporaryTargetById(Ref ref, String id) async {
  final repository = await ref.watch(nightscoutRepositoryProvider.future);
  return await repository.fetchLastTemporaryTargetById(id);
}

@riverpod
Future<List<BolusWizard>> bolusWizards(Ref ref) async {
  final repository = await ref.watch(nightscoutRepositoryProvider.future);
  return await repository.fetchBolusWizardsOnDay(clock.now());
}

@riverpod
Future<List<Glucose>> glucoseWithLimit(Ref ref, int limit) async {
  final repository = await ref.watch(nightscoutRepositoryProvider.future);
  return await repository.fetchLastGlucoseWithLimit(limit);
}

@riverpod
Future<List<Treatment>> treatmentsAfter(Ref ref, DateTime after) async {
  final repository = await ref.watch(nightscoutRepositoryProvider.future);
  return await repository.fetchTreatmentsAfter(after);
}

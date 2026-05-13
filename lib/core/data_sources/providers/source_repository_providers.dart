import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../cloud/cloud_device_status_source_repository.dart';
import '../cloud/cloud_glucose_source_repository.dart';
import '../cloud/cloud_treatment_source_repository.dart';
import '../config/data_source_config.dart';
import '../config/data_source_config_provider.dart';
import '../domain/data_source_exceptions.dart';
import '../domain/device_status_source_repository.dart';
import '../domain/glucose_source_repository.dart';
import '../domain/treatment_source_repository.dart';
import '../nightscout/providers/nightscout_repository_provider.dart';
import '../nightscout/repository/nightscout_repository.dart';

part 'source_repository_providers.g.dart';

Future<NightscoutRepository> _nightscoutRepository(Ref ref) {
  return ref.watch(nightscoutRepositoryProvider.future);
}

@riverpod
Future<GlucoseSourceRepository> glucoseSourceRepository(Ref ref) async {
  final config = await ref.watch(dataSourceConfigProvider.future);

  switch (config.bgSource) {
    case BgSource.cloud:
      final nightscoutRepository = await _nightscoutRepository(ref);
      return CloudGlucoseSourceRepository(nightscoutRepository);
    case BgSource.aaps:
      throw const UnsupportedDataSourceException(
        'AAPS glucose source is not implemented yet',
      );
    case BgSource.xdrip:
      throw const UnsupportedDataSourceException(
        'xDrip+ glucose source is not implemented yet',
      );
  }
}

@riverpod
Future<TreatmentSourceRepository> treatmentSourceRepository(Ref ref) async {
  final config = await ref.watch(dataSourceConfigProvider.future);

  switch (config.eventSource) {
    case EventSource.cloud:
      final nightscoutRepository = await _nightscoutRepository(ref);
      return CloudTreatmentSourceRepository(nightscoutRepository);
    case EventSource.aaps:
      throw const UnsupportedDataSourceException(
        'AAPS treatment source is not implemented yet',
      );
  }
}

@riverpod
Future<DeviceStatusSourceRepository> deviceStatusSourceRepository(
  Ref ref,
) async {
  final config = await ref.watch(dataSourceConfigProvider.future);

  switch (config.eventSource) {
    case EventSource.cloud:
      final nightscoutRepository = await _nightscoutRepository(ref);
      return CloudDeviceStatusSourceRepository(nightscoutRepository);
    case EventSource.aaps:
      throw const UnsupportedDataSourceException(
        'AAPS device status source is not implemented yet',
      );
  }
}

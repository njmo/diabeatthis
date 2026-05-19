import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../drift/providers/database_provider.dart';
import '../cloud/cloud_device_status_source_repository.dart';
import '../cloud/cloud_glucose_source_repository.dart';
import '../cloud/cloud_treatment_source_repository.dart';
import '../cloud/history/cloud_device_status_history_repository.dart';
import '../cloud/history/cloud_glucose_history_repository.dart';
import '../cloud/history/cloud_treatments_history_repository.dart';
import '../config/data_source_config.dart';
import '../config/data_source_config_provider.dart';
import '../domain/data_source_exceptions.dart';
import '../domain/device_status_history_repository.dart';
import '../domain/device_status_source_repository.dart';
import '../domain/glucose_history_repository.dart';
import '../domain/glucose_source_repository.dart';
import '../domain/treatment_source_repository.dart';
import '../domain/treatments_history_repository.dart';
import '../local_mirror/history/local_device_status_history_repository.dart';
import '../local_mirror/history/local_glucose_history_repository.dart';
import '../local_mirror/history/local_treatments_history_repository.dart';
import '../local_mirror/providers/local_mirror_writer_provider.dart';
import '../local_mirror/repositories/mirroring_device_status_history_repository.dart';
import '../local_mirror/repositories/mirroring_device_status_source_repository.dart';
import '../local_mirror/repositories/mirroring_glucose_history_repository.dart';
import '../local_mirror/repositories/mirroring_glucose_source_repository.dart';
import '../local_mirror/repositories/mirroring_treatment_source_repository.dart';
import '../local_mirror/repositories/mirroring_treatments_history_repository.dart';
import '../local_mirror/services/local_mirror_writer.dart';
import '../nightscout/providers/nightscout_repository_provider.dart';

part 'source_repository_providers.g.dart';

@Riverpod(keepAlive: true)
Future<GlucoseSourceRepository> glucoseSourceRepository(Ref ref) async {
  final config = await ref.watch(dataSourceConfigProvider.future);

  switch (config.bgSource) {
    case BgSource.cloud:
      final nightscoutRepository = await ref.watch(
        nightscoutRepositoryProvider.future,
      );
      final repository = CloudGlucoseSourceRepository(nightscoutRepository);
      if (!config.mirrorToLocal) return repository;

      return MirroringGlucoseSourceRepository(
        delegate: repository,
        mirrorWriter: _localMirrorWriter(ref),
      );
    case BgSource.aaps:
      throw const UnsupportedDataSourceException(
        'AAPS glucose source is push-based and cannot be polled',
      );
    case BgSource.xdrip:
      throw const UnsupportedDataSourceException(
        'xDrip+ glucose source is push-based and cannot be polled',
      );
  }
}

@Riverpod(keepAlive: true)
Future<TreatmentSourceRepository> treatmentsSourceRepository(Ref ref) async {
  final config = await ref.watch(dataSourceConfigProvider.future);

  switch (config.treatmentsSource) {
    case TreatmentsSource.cloud:
      final nightscoutRepository = await ref.watch(
        nightscoutRepositoryProvider.future,
      );
      final repository = CloudTreatmentSourceRepository(nightscoutRepository);
      if (!config.mirrorToLocal) return repository;

      return MirroringTreatmentSourceRepository(
        delegate: repository,
        mirrorWriter: _localMirrorWriter(ref),
        source: config.treatmentsSource,
      );
    case TreatmentsSource.aaps:
      throw const UnsupportedDataSourceException(
        'AAPS treatment source is not implemented yet',
      );
  }
}

@Riverpod(keepAlive: true)
Future<GlucoseHistoryRepository> glucoseHistoryRepository(Ref ref) async {
  final config = await ref.watch(dataSourceConfigProvider.future);

  switch (config.historySource) {
    case HistorySource.cloud:
      final nightscoutRepository = await ref.watch(
        nightscoutRepositoryProvider.future,
      );
      final repository = CloudGlucoseHistoryRepository(nightscoutRepository);
      if (!config.mirrorToLocal) return repository;

      return MirroringGlucoseHistoryRepository(
        delegate: repository,
        mirrorWriter: _localMirrorWriter(ref),
      );
    case HistorySource.local:
      return LocalGlucoseHistoryRepository(
        ref.watch(databaseProvider).localMirrorDao,
      );
  }
}

@Riverpod(keepAlive: true)
Future<TreatmentsHistoryRepository> treatmentsHistoryRepository(Ref ref) async {
  final config = await ref.watch(dataSourceConfigProvider.future);

  switch (config.historySource) {
    case HistorySource.cloud:
      final nightscoutRepository = await ref.watch(
        nightscoutRepositoryProvider.future,
      );
      final repository = CloudTreatmentsHistoryRepository(nightscoutRepository);
      if (!config.mirrorToLocal) return repository;

      return MirroringTreatmentsHistoryRepository(
        delegate: repository,
        mirrorWriter: _localMirrorWriter(ref),
        source: TreatmentsSource.cloud,
      );
    case HistorySource.local:
      return LocalTreatmentsHistoryRepository(
        ref.watch(databaseProvider).localMirrorDao,
      );
  }
}

@Riverpod(keepAlive: true)
Future<DeviceStatusHistoryRepository> deviceStatusHistoryRepository(
  Ref ref,
) async {
  final config = await ref.watch(dataSourceConfigProvider.future);

  switch (config.historySource) {
    case HistorySource.cloud:
      final nightscoutRepository = await ref.watch(
        nightscoutRepositoryProvider.future,
      );
      final repository = CloudDeviceStatusHistoryRepository(
        nightscoutRepository,
      );
      if (!config.mirrorToLocal) return repository;

      return MirroringDeviceStatusHistoryRepository(
        delegate: repository,
        mirrorWriter: _localMirrorWriter(ref),
      );
    case HistorySource.local:
      return LocalDeviceStatusHistoryRepository(
        ref.watch(databaseProvider).localMirrorDao,
      );
  }
}

@Riverpod(keepAlive: true)
Future<DeviceStatusSourceRepository> deviceStatusSourceRepository(
  Ref ref,
) async {
  final config = await ref.watch(dataSourceConfigProvider.future);

  switch (config.pumpStatusSource) {
    case PumpStatusSource.cloud:
      final nightscoutRepository = await ref.watch(
        nightscoutRepositoryProvider.future,
      );
      final repository = CloudDeviceStatusSourceRepository(
        nightscoutRepository,
      );
      if (!config.mirrorToLocal) return repository;

      return MirroringDeviceStatusSourceRepository(
        delegate: repository,
        mirrorWriter: _localMirrorWriter(ref),
      );
    case PumpStatusSource.aaps:
      throw const UnsupportedDataSourceException(
        'AAPS pump status source is push-based and cannot be polled',
      );
  }
}

LocalMirrorWriter _localMirrorWriter(Ref ref) {
  if (!ref.mounted) {
    throw StateError('Source repository provider was disposed while loading');
  }

  return ref.read(localMirrorWriterProvider);
}

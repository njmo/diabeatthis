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
import '../local_mirror/providers/local_mirror_writer_provider.dart';
import '../local_mirror/repositories/mirroring_device_status_source_repository.dart';
import '../local_mirror/repositories/mirroring_glucose_source_repository.dart';
import '../local_mirror/repositories/mirroring_treatment_source_repository.dart';
import '../local_mirror/services/local_mirror_writer.dart';
import '../nightscout/providers/nightscout_repository_provider.dart';

part 'source_repository_providers.g.dart';

@Riverpod(keepAlive: true)
Future<GlucoseSourceRepository> glucoseSourceRepository(Ref ref) async {
  final nightscoutRepositoryFuture = ref.watch(
    nightscoutRepositoryProvider.future,
  );
  final config = await ref.watch(dataSourceConfigProvider.future);

  switch (config.bgSource) {
    case BgSource.cloud:
      final nightscoutRepository = await nightscoutRepositoryFuture;
      final repository = CloudGlucoseSourceRepository(nightscoutRepository);
      if (!config.mirrorToLocal) return repository;

      return MirroringGlucoseSourceRepository(
        delegate: repository,
        mirrorWriter: _localMirrorWriter(ref),
        source: config.bgSource,
      );
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

@Riverpod(keepAlive: true)
Future<TreatmentSourceRepository> treatmentSourceRepository(Ref ref) async {
  final nightscoutRepositoryFuture = ref.watch(
    nightscoutRepositoryProvider.future,
  );
  final config = await ref.watch(dataSourceConfigProvider.future);

  switch (config.eventSource) {
    case EventSource.cloud:
      final nightscoutRepository = await nightscoutRepositoryFuture;
      final repository = CloudTreatmentSourceRepository(nightscoutRepository);
      if (!config.mirrorToLocal) return repository;

      return MirroringTreatmentSourceRepository(
        delegate: repository,
        mirrorWriter: _localMirrorWriter(ref),
        source: config.eventSource,
      );
    case EventSource.aaps:
      throw const UnsupportedDataSourceException(
        'AAPS treatment source is not implemented yet',
      );
  }
}

@Riverpod(keepAlive: true)
Future<DeviceStatusSourceRepository> deviceStatusSourceRepository(
  Ref ref,
) async {
  final nightscoutRepositoryFuture = ref.watch(
    nightscoutRepositoryProvider.future,
  );
  final config = await ref.watch(dataSourceConfigProvider.future);

  switch (config.eventSource) {
    case EventSource.cloud:
      final nightscoutRepository = await nightscoutRepositoryFuture;
      final repository = CloudDeviceStatusSourceRepository(
        nightscoutRepository,
      );
      if (!config.mirrorToLocal) return repository;

      return MirroringDeviceStatusSourceRepository(
        delegate: repository,
        mirrorWriter: _localMirrorWriter(ref),
      );
    case EventSource.aaps:
      throw const UnsupportedDataSourceException(
        'AAPS device status source is not implemented yet',
      );
  }
}

LocalMirrorWriter _localMirrorWriter(Ref ref) {
  if (!ref.mounted) {
    throw StateError('Source repository provider was disposed while loading');
  }

  return ref.read(localMirrorWriterProvider);
}

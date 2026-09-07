import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cloud/history/cloud_device_status_history_repository.dart';
import '../cloud/history/cloud_glucose_history_repository.dart';
import '../cloud/history/cloud_treatments_history_repository.dart';
import '../config/data_source_config.dart';
import '../domain/device_status_history_repository.dart';
import '../domain/glucose_history_repository.dart';
import '../domain/treatments_history_repository.dart';
import '../local_mirror/providers/local_mirror_writer_provider.dart';
import '../local_mirror/repositories/mirroring_device_status_history_repository.dart';
import '../local_mirror/repositories/mirroring_glucose_history_repository.dart';
import '../local_mirror/repositories/mirroring_treatments_history_repository.dart';
import '../nightscout/providers/nightscout_repository_provider.dart';

// Explicit downloads bypass source preferences and populate the local mirror.
final onDemandHistoryRepositoriesProvider =
    FutureProvider<
      ({
        GlucoseHistoryRepository glucose,
        TreatmentsHistoryRepository treatments,
        DeviceStatusHistoryRepository deviceStatuses,
      })
    >((ref) async {
      final writer = ref.watch(localMirrorWriterProvider);
      final nightscout = await ref.watch(nightscoutRepositoryProvider.future);
      return (
        glucose: MirroringGlucoseHistoryRepository(
          delegate: CloudGlucoseHistoryRepository(nightscout),
          mirrorWriter: writer,
        ),
        treatments: MirroringTreatmentsHistoryRepository(
          delegate: CloudTreatmentsHistoryRepository(nightscout),
          mirrorWriter: writer,
          source: TreatmentsSource.cloud,
        ),
        deviceStatuses: MirroringDeviceStatusHistoryRepository(
          delegate: CloudDeviceStatusHistoryRepository(nightscout),
          mirrorWriter: writer,
        ),
      );
    });

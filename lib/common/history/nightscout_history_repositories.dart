import '../../core/data_sources/cloud/history/cloud_device_status_history_repository.dart';
import '../../core/data_sources/cloud/history/cloud_glucose_history_repository.dart';
import '../../core/data_sources/cloud/history/cloud_treatments_history_repository.dart';
import '../../core/data_sources/domain/device_status_history_repository.dart';
import '../../core/data_sources/domain/glucose_history_repository.dart';
import '../../core/data_sources/domain/treatments_history_repository.dart';
import '../../core/data_sources/nightscout/repository/nightscout_repository.dart';

/// Read-only history with no local patient database, mirroring or event overlay.
class NightscoutHistoryRepositories {
  NightscoutHistoryRepositories(NightscoutRepository repository)
    : glucose = CloudGlucoseHistoryRepository(repository),
      treatments = CloudTreatmentsHistoryRepository(repository),
      deviceStatuses = CloudDeviceStatusHistoryRepository(repository);

  final GlucoseHistoryRepository glucose;
  final TreatmentsHistoryRepository treatments;
  final DeviceStatusHistoryRepository deviceStatuses;
}

import '../../../domain/model/device_status.dart';
import '../../../domain/model/glucose.dart';
import '../../../domain/model/treatment_base.dart';
import '../../../drift/dao/local_mirror_dao.dart';
import '../../config/data_source_config.dart';
import '../mappers/device_status_drift_mapper.dart';
import '../mappers/local_glucose_mirror_mapper.dart';
import '../mappers/local_treatment_mirror_mapper.dart';

class LocalMirrorWriter {
  const LocalMirrorWriter(this._dao);

  final LocalMirrorDao _dao;

  Future<void> mirrorGlucose(
    Iterable<Glucose> readings,
    BgSource source,
  ) async {
    for (final reading in readings) {
      await _dao.upsertGlucoseReading(reading.toLocalMirrorCompanion(source));
    }
  }

  Future<void> mirrorTreatments(
    Iterable<Treatment> treatments,
    EventSource source,
  ) async {
    for (final treatment in treatments) {
      final companion = treatment.toLocalMirrorCompanion(source);
      if (companion == null) continue;

      await _dao.upsertTreatmentEvent(companion);
    }
  }

  Future<void> mirrorDeviceStatuses(Iterable<DeviceStatus> statuses) async {
    for (final status in statuses) {
      await _dao.upsertDeviceStatus(status.toDriftCompanion());
    }
  }
}

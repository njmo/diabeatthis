import '../../../domain/model/bolus_wizard.dart';
import '../../../domain/model/correction_bolus.dart';
import '../../../domain/model/device_status.dart';
import '../../../domain/model/extended_carb.dart';
import '../../../domain/model/glucose.dart';
import '../../../domain/model/manual_bolus.dart';
import '../../../domain/model/temporary_target.dart';
import '../../../domain/model/treat.dart';
import '../../../domain/model/treatment_base.dart';
import '../../../drift/dao/local_mirror_dao.dart';
import '../../config/data_source_config.dart';
import '../mappers/bolus_wizard_drift_mapper.dart';
import '../mappers/correction_bolus_drift_mapper.dart';
import '../mappers/device_status_drift_mapper.dart';
import '../mappers/extended_carb_drift_mapper.dart';
import '../mappers/glucose_drift_mapper.dart';
import '../mappers/manual_bolus_drift_mapper.dart';
import '../mappers/temporary_target_drift_mapper.dart';
import '../mappers/treat_drift_mapper.dart';

class LocalMirrorWriter {
  const LocalMirrorWriter(this._dao);

  final LocalMirrorDao _dao;

  Future<void> mirrorGlucose(Iterable<Glucose> readings) async {
    for (final reading in readings) {
      await _dao.upsertGlucoseReading(reading.toCompanion());
    }
  }

  Future<void> mirrorTreatments(
    Iterable<Treatment> treatments,
    EventSource source,
  ) async {
    for (final treatment in treatments) {
      switch (treatment) {
        case BolusWizard():
          await _dao.upsertBolusWizard(treatment.toCompanion(source));
        case TemporaryTarget():
          await _dao.upsertTemporaryTarget(treatment.toCompanion(source));
        case CorrectionBolus():
          await _dao.upsertCorrectionBolus(treatment.toCompanion(source));
        case ManualBolus():
          await _dao.upsertManualBolus(treatment.toCompanion(source));
        case Treat():
          await _dao.upsertTreat(treatment.toCompanion(source));
        case ExtendedCarb():
          await _dao.upsertExtendedCarb(treatment.toCompanion(source));
        default:
          continue;
      }
    }
  }

  Future<void> mirrorDeviceStatuses(Iterable<DeviceStatus> statuses) async {
    for (final status in statuses) {
      await _dao.upsertDeviceStatus(status.toCompanion());
    }
  }
}

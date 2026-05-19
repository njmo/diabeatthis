import '../../../domain/model/temporary_target.dart';
import '../../../domain/model/treatment_base.dart';
import '../../../drift/dao/local_mirror_dao.dart';
import '../../domain/treatments_history_repository.dart';
import '../mappers/bolus_wizard_drift_mapper.dart';
import '../mappers/correction_bolus_drift_mapper.dart';
import '../mappers/extended_carb_drift_mapper.dart';
import '../mappers/manual_bolus_drift_mapper.dart';
import '../mappers/temporary_target_drift_mapper.dart';
import '../mappers/treat_drift_mapper.dart';

class LocalTreatmentsHistoryRepository implements TreatmentsHistoryRepository {
  const LocalTreatmentsHistoryRepository(this._dao);

  final LocalMirrorDao _dao;

  @override
  Future<List<Treatment>> fetchTreatmentsBetween(
    DateTime start,
    DateTime end,
  ) async {
    final treatments =
        <Treatment>[
          ...(await _dao.getBolusWizardsBetween(
            start,
            end,
          )).map((row) => row.toDomain()),
          ...(await _dao.getTemporaryTargetsBetween(
            start,
            end,
          )).map((row) => row.toDomain()),
          ...(await _dao.getCorrectionBolusesBetween(
            start,
            end,
          )).map((row) => row.toDomain()),
          ...(await _dao.getManualBolusesBetween(
            start,
            end,
          )).map((row) => row.toDomain()),
          ...(await _dao.getTreatsBetween(
            start,
            end,
          )).map((row) => row.toDomain()),
          ...(await _dao.getExtendedCarbsBetween(
            start,
            end,
          )).map((row) => row.toDomain()),
        ]..sort((a, b) {
          final aCreatedAt =
              a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bCreatedAt =
              b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return aCreatedAt.compareTo(bCreatedAt);
        });

    return treatments;
  }

  @override
  Future<TemporaryTarget?> fetchLastTemporaryTarget() async {
    return (await _dao.getLastTemporaryTarget())?.toDomain();
  }
}

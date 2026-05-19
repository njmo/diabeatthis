import 'package:drift/drift.dart';

import '../database_impl.dart';

part 'local_mirror_dao.g.dart';

@DriftAccessor(
  include: {
    '../schemas/tables/glucose_reading.drift',
    '../schemas/tables/device_status.drift',
    '../schemas/tables/bolus_wizard.drift',
    '../schemas/tables/temporary_target.drift',
    '../schemas/tables/correction_bolus.drift',
    '../schemas/tables/manual_bolus.drift',
    '../schemas/tables/treat.drift',
    '../schemas/tables/extended_carb.drift',
  },
)
class LocalMirrorDao extends DatabaseAccessor<DatabaseImpl>
    with _$LocalMirrorDaoMixin {
  LocalMirrorDao(super.db);

  Future<void> upsertGlucoseReading(GlucoseReadingCompanion reading) {
    final table = db.glucoseReading;

    return into(table).insert(
      reading,
      onConflict: DoUpdate((_) => reading, target: [table.createdAt]),
    );
  }

  Future<void> upsertBolusWizard(BolusWizardCompanion event) {
    final table = db.bolusWizard;

    return into(table).insert(
      event,
      onConflict: DoUpdate((_) => event, target: [table.createdAt]),
    );
  }

  Future<void> upsertTemporaryTarget(TemporaryTargetCompanion event) {
    final table = db.temporaryTarget;

    return into(table).insert(
      event,
      onConflict: DoUpdate((_) => event, target: [table.createdAt]),
    );
  }

  Future<void> upsertCorrectionBolus(CorrectionBolusCompanion event) {
    final table = db.correctionBolus;

    return into(table).insert(
      event,
      onConflict: DoUpdate((_) => event, target: [table.createdAt]),
    );
  }

  Future<void> upsertManualBolus(ManualBolusCompanion event) {
    final table = db.manualBolus;

    return into(table).insert(
      event,
      onConflict: DoUpdate((_) => event, target: [table.createdAt]),
    );
  }

  Future<void> upsertTreat(TreatCompanion event) {
    final table = db.treat;

    return into(table).insert(
      event,
      onConflict: DoUpdate((_) => event, target: [table.createdAt]),
    );
  }

  Future<void> upsertExtendedCarb(ExtendedCarbCompanion event) {
    final table = db.extendedCarb;

    return into(table).insert(
      event,
      onConflict: DoUpdate((_) => event, target: [table.createdAt]),
    );
  }

  Future<void> deleteBolusWizardByCreatedAt(DateTime? createdAt) async {
    final table = db.bolusWizard;
    final reference = _matchesTreatmentReference(table.createdAt, createdAt);
    if (reference == null) return;

    await (delete(table)..where((row) => reference)).go();
  }

  Future<void> deleteTemporaryTargetByCreatedAt(DateTime? createdAt) async {
    final table = db.temporaryTarget;
    final reference = _matchesTreatmentReference(table.createdAt, createdAt);
    if (reference == null) return;

    await (delete(table)..where((row) => reference)).go();
  }

  Future<void> deleteCorrectionBolusByCreatedAt(DateTime? createdAt) async {
    final table = db.correctionBolus;
    final reference = _matchesTreatmentReference(table.createdAt, createdAt);
    if (reference == null) return;

    await (delete(table)..where((row) => reference)).go();
  }

  Future<void> deleteManualBolusByCreatedAt(DateTime? createdAt) async {
    final table = db.manualBolus;
    final reference = _matchesTreatmentReference(table.createdAt, createdAt);
    if (reference == null) return;

    await (delete(table)..where((row) => reference)).go();
  }

  Future<void> deleteTreatByCreatedAt(DateTime? createdAt) async {
    final table = db.treat;
    final reference = _matchesTreatmentReference(table.createdAt, createdAt);
    if (reference == null) return;

    await (delete(table)..where((row) => reference)).go();
  }

  Future<void> deleteExtendedCarbByCreatedAt(DateTime? createdAt) async {
    final table = db.extendedCarb;
    final reference = _matchesTreatmentReference(table.createdAt, createdAt);
    if (reference == null) return;

    await (delete(table)..where((row) => reference)).go();
  }

  Future<void> upsertDeviceStatus(DeviceStatusCompanion status) {
    final table = db.deviceStatus;

    return into(table).insert(
      status,
      onConflict: DoUpdate((_) => status, target: [table.createdAt]),
    );
  }

  Future<List<GlucoseReadingData>> getGlucoseReadingsBetween(
    DateTime start,
    DateTime end, {
    String? source,
  }) {
    final query = select(db.glucoseReading)
      ..where(
        (row) => row.createdAt.isBetweenValues(
          start.millisecondsSinceEpoch,
          end.millisecondsSinceEpoch,
        ),
      )
      ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]);

    if (source != null) {
      query.where((row) => row.source.equals(source));
    }

    return query.get();
  }

  Future<List<GlucoseReadingData>> getRecentGlucoseReadings(int limit) async {
    final rows =
        await (select(db.glucoseReading)
              ..orderBy([(row) => OrderingTerm.desc(row.createdAt)])
              ..limit(limit))
            .get();

    return rows.reversed.toList();
  }

  Future<List<BolusWizardData>> getBolusWizardsBetween(
    DateTime start,
    DateTime end, {
    String? source,
  }) {
    final query = select(db.bolusWizard)
      ..where((row) => _createdAtBetween(row.createdAt, start, end))
      ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]);

    if (source != null) {
      query.where((row) => row.source.equals(source));
    }

    return query.get();
  }

  Future<List<TemporaryTargetData>> getTemporaryTargetsBetween(
    DateTime start,
    DateTime end, {
    String? source,
  }) {
    final query = select(db.temporaryTarget)
      ..where((row) => _createdAtBetween(row.createdAt, start, end))
      ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]);

    if (source != null) {
      query.where((row) => row.source.equals(source));
    }

    return query.get();
  }

  Future<TemporaryTargetData?> getLastTemporaryTarget() {
    final query = select(db.temporaryTarget)
      ..orderBy([(row) => OrderingTerm.desc(row.createdAt)])
      ..limit(1);

    return query.getSingleOrNull();
  }

  Future<List<CorrectionBolusData>> getCorrectionBolusesBetween(
    DateTime start,
    DateTime end, {
    String? source,
  }) {
    final query = select(db.correctionBolus)
      ..where((row) => _createdAtBetween(row.createdAt, start, end))
      ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]);

    if (source != null) {
      query.where((row) => row.source.equals(source));
    }

    return query.get();
  }

  Future<List<ManualBolusData>> getManualBolusesBetween(
    DateTime start,
    DateTime end, {
    String? source,
  }) {
    final query = select(db.manualBolus)
      ..where((row) => _createdAtBetween(row.createdAt, start, end))
      ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]);

    if (source != null) {
      query.where((row) => row.source.equals(source));
    }

    return query.get();
  }

  Future<List<TreatData>> getTreatsBetween(
    DateTime start,
    DateTime end, {
    String? source,
  }) {
    final query = select(db.treat)
      ..where((row) => _createdAtBetween(row.createdAt, start, end))
      ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]);

    if (source != null) {
      query.where((row) => row.source.equals(source));
    }

    return query.get();
  }

  Future<List<ExtendedCarbData>> getExtendedCarbsBetween(
    DateTime start,
    DateTime end, {
    String? source,
  }) {
    final query = select(db.extendedCarb)
      ..where((row) => _createdAtBetween(row.createdAt, start, end))
      ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]);

    if (source != null) {
      query.where((row) => row.source.equals(source));
    }

    return query.get();
  }

  Future<List<DeviceStatusData>> getDeviceStatusesBetween(
    DateTime start,
    DateTime end, {
    String? source,
  }) {
    final query = select(db.deviceStatus)
      ..where(
        (row) => row.createdAt.isBetweenValues(
          start.millisecondsSinceEpoch,
          end.millisecondsSinceEpoch,
        ),
      )
      ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]);

    if (source != null) {
      query.where((row) => row.source.equals(source));
    }

    return query.get();
  }

  Future<DeviceStatusData?> getLastDeviceStatusBefore(DateTime before) {
    final query = select(db.deviceStatus)
      ..where(
        (row) =>
            row.createdAt.isSmallerThanValue(before.millisecondsSinceEpoch),
      )
      ..orderBy([(row) => OrderingTerm.desc(row.createdAt)])
      ..limit(1);

    return query.getSingleOrNull();
  }
}

Expression<bool> _createdAtBetween(
  GeneratedColumn<int> column,
  DateTime start,
  DateTime end,
) {
  return column.isBetweenValues(
    start.millisecondsSinceEpoch,
    end.millisecondsSinceEpoch,
  );
}

Expression<bool>? _matchesTreatmentReference(
  GeneratedColumn<int> createdAtColumn,
  DateTime? createdAt,
) {
  final createdAtValue = createdAt?.millisecondsSinceEpoch;

  if (createdAtValue != null) {
    return createdAtColumn.equals(createdAtValue);
  }

  return null;
}

import 'package:drift/drift.dart';

import '../database_impl.dart';
import '../helpers/merge_bolus_wizard.dart';
import '../helpers/validate_wizard_identity.dart';
import '../models/wizard_identity_conflict.dart';

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

  Future<void> deleteSpotGlucose(String source, String externalId) async {
    await (delete(db.glucoseReading)..where(
          (t) =>
              t.source.equals(source) &
              t.externalId.equals(externalId) &
              t.type.equals('cgm').not(),
        ))
        .go();
  }

  Future<void> upsertSpotGlucose(GlucoseReadingCompanion reading) =>
      transaction(() async {
        await deleteSpotGlucose(
          reading.source.value,
          reading.externalId.value!,
        );
        await into(db.glucoseReading).insert(reading);
      });

  Future<List<GlucoseReadingData>> getSpotGlucoseBetween(
    DateTime start,
    DateTime end,
  ) =>
      (select(db.glucoseReading)..where(
            (t) =>
                t.type.equals('cgm').not() &
                t.createdAt.isBetweenValues(
                  start.millisecondsSinceEpoch,
                  end.millisecondsSinceEpoch,
                ),
          ))
          .get();

  Future<void> upsertGlucoseReading(GlucoseReadingCompanion reading) {
    final table = db.glucoseReading;

    return into(table).insert(
      reading,
      onConflict: DoUpdate(
        (_) => reading,
        target: [table.createdAt, table.type, table.measurementId],
      ),
    );
  }

  Future<void> upsertBolusWizard(BolusWizardCompanion event) =>
      transaction(() async {
        final table = db.bolusWizard;
        if (event.nightscoutId.present &&
            event.nightscoutId.value != null &&
            event.remoteSource.present &&
            event.remoteSource.value != null) {
          final remoteMatch =
              await (select(table)..where(
                    (row) =>
                        row.nightscoutId.equals(event.nightscoutId.value!) &
                        row.remoteSource.equals(event.remoteSource.value!),
                  ))
                  .getSingleOrNull();
          if (remoteMatch != null &&
              remoteMatch.createdAt != event.createdAt.value) {
            throw WizardIdentityConflict(
              'A known remote wizard has a different timestamp',
            );
          }
        }
        final existing =
            await (select(table)
                  ..where((row) => row.createdAt.equals(event.createdAt.value)))
                .getSingleOrNull();
        if (existing == null) {
          await into(table).insert(event);
        } else {
          await (update(table)
                ..where((row) => row.localId.equals(existing.localId)))
              .write(mergeBolusWizard(existing, event));
        }
        final saved =
            await (select(table)
                  ..where((row) => row.createdAt.equals(event.createdAt.value)))
                .getSingle();
        await db.mealWizardLinkDao.reconcile(saved);
      });

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

  Future<void> deleteBolusWizard(BolusWizardCompanion event) =>
      transaction(() async {
        final table = db.bolusWizard;
        final stored =
            await (select(table)
                  ..where((row) => row.createdAt.equals(event.createdAt.value)))
                .getSingleOrNull();
        if (stored == null) return;
        validateWizardIdentity(stored, event);
        await (delete(
          table,
        )..where((row) => row.localId.equals(stored.localId))).go();
      });

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
      ..where((row) => row.type.equals('cgm'))
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
              ..where((row) => row.type.equals('cgm'))
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

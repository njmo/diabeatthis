import 'package:drift/drift.dart';

import '../database_impl.dart';

part 'local_mirror_dao.g.dart';

@DriftAccessor(include: {'../schemas/tables/local_mirror.drift'})
class LocalMirrorDao extends DatabaseAccessor<DatabaseImpl>
    with _$LocalMirrorDaoMixin {
  LocalMirrorDao(super.db);

  Future<void> upsertGlucoseReading(LocalGlucoseReadingCompanion reading) {
    final table = db.localGlucoseReading;

    return into(table).insert(
      reading,
      onConflict: UpsertMultiple([
        DoUpdate(
          (_) => reading,
          target: [table.source, table.externalId],
          targetCondition: (row) => row.externalId.isNotNull(),
        ),
        DoUpdate(
          (_) => reading,
          target: [table.source, table.recordedAt, table.sgv],
        ),
      ]),
    );
  }

  Future<void> upsertTreatmentEvent(LocalTreatmentEventCompanion event) {
    final table = db.localTreatmentEvent;

    return into(table).insert(
      event,
      onConflict: DoUpdate(
        (_) => event,
        target: [table.source, table.externalId],
        targetCondition: (row) => row.externalId.isNotNull(),
      ),
    );
  }

  Future<void> upsertDeviceStatus(DeviceStatusCompanion status) {
    final table = db.deviceStatus;

    return into(table).insert(
      status,
      onConflict: UpsertMultiple([
        DoUpdate(
          (_) => status,
          target: [table.source, table.externalId],
          targetCondition: (row) => row.externalId.isNotNull(),
        ),
        DoUpdate((_) => status, target: [table.source, table.recordedAt]),
      ]),
    );
  }

  Future<List<LocalGlucoseReadingData>> getGlucoseReadingsBetween(
    DateTime start,
    DateTime end, {
    String? source,
  }) {
    final query = select(db.localGlucoseReading)
      ..where(
        (row) => row.recordedAt.isBetweenValues(
          start.millisecondsSinceEpoch,
          end.millisecondsSinceEpoch,
        ),
      )
      ..orderBy([(row) => OrderingTerm.asc(row.recordedAt)]);

    if (source != null) {
      query.where((row) => row.source.equals(source));
    }

    return query.get();
  }

  Future<List<LocalTreatmentEventData>> getTreatmentEventsBetween(
    DateTime start,
    DateTime end, {
    String? source,
  }) {
    final query = select(db.localTreatmentEvent)
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

  Future<List<DeviceStatusData>> getDeviceStatusesBetween(
    DateTime start,
    DateTime end, {
    String? source,
  }) {
    final query = select(db.deviceStatus)
      ..where(
        (row) => row.recordedAt.isBetweenValues(
          start.millisecondsSinceEpoch,
          end.millisecondsSinceEpoch,
        ),
      )
      ..orderBy([(row) => OrderingTerm.asc(row.recordedAt)]);

    if (source != null) {
      query.where((row) => row.source.equals(source));
    }

    return query.get();
  }
}

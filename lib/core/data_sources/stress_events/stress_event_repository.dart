import 'package:clock/clock.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/model/stress_event.dart';
import '../../domain/model/stress_level.dart';
import '../../drift/database_impl.dart' hide StressEvent;
import '../../drift/providers/database_provider.dart';

final stressEventRepositoryProvider = Provider<StressEventRepository>(
  (ref) => StressEventRepository(ref.watch(databaseProvider)),
);

final stressEventsProvider = StreamProvider<List<StressEvent>>(
  (ref) => ref.watch(stressEventRepositoryProvider).watchEvents(),
);

class StressEventRepository {
  const StressEventRepository(this.db);

  final DatabaseImpl db;

  Stream<List<StressEvent>> watchEvents() =>
      (db.select(db.stressEvent)..orderBy([
            (table) => OrderingTerm.desc(table.occurredAt),
            (table) => OrderingTerm.desc(table.id),
          ]))
          .watch()
          .map((rows) => rows.map(toDomain).toList());

  Future<List<StressEvent>> between(DateTime start, DateTime end) async {
    final rows =
        await (db.select(db.stressEvent)
              ..where(
                (table) =>
                    table.occurredAt.isSmallerOrEqualValue(
                      end.millisecondsSinceEpoch,
                    ) &
                    (table.occurredAt.isBiggerOrEqualValue(
                          start.millisecondsSinceEpoch,
                        ) |
                        table.endedAt.isBiggerOrEqualValue(
                          start.millisecondsSinceEpoch,
                        )),
              )
              ..orderBy([(table) => OrderingTerm.asc(table.occurredAt)]))
            .get();
    return rows.map(toDomain).toList();
  }

  /// Repeated imports update the same source/external ID; manual entries append.
  Future<StressEvent> save(StressEvent event) async {
    if (event.source.trim().isEmpty ||
        (event.externalId != null && event.externalId!.trim().isEmpty)) {
      throw ArgumentError('Source and external identity must not be empty');
    }
    final end = event.endedAt;
    if (end != null && !end.isAfter(event.occurredAt)) {
      throw ArgumentError('Invalid stress interval');
    }
    final now = clock.now();
    if (event.occurredAt.isAfter(now)) {
      throw ArgumentError.value(
        event.occurredAt,
        'occurredAt',
        'Event is in the future',
      );
    }
    final existingRow = event.id != null
        ? await find(event.id!)
        : event.externalId == null
        ? null
        : await findExternal(event.source, event.externalId!);
    if (existingRow != null && existingRow.hasSameContent(event)) {
      return existingRow;
    }
    final entry = StressEventCompanion.insert(
      id: existingRow == null ? const Value.absent() : Value(existingRow.id!),
      source: event.source,
      externalId: Value(event.externalId),
      notes: Value(event.notes),
      endedAt: Value(event.endedAt?.millisecondsSinceEpoch),
      stressLevel: event.stressLevel.name,
      occurredAt: event.occurredAt.millisecondsSinceEpoch,
      recordedAt: now.millisecondsSinceEpoch,
    );
    final saved = await db
        .into(db.stressEvent)
        .insertReturning(
          entry,
          onConflict: DoUpdate(
            (_) => entry,
            target: existingRow == null
                ? [db.stressEvent.source, db.stressEvent.externalId]
                : [db.stressEvent.id],
          ),
        );
    return toDomain(saved);
  }

  Future<StressEvent?> findExternal(String source, String externalId) async {
    final row =
        await (db.select(db.stressEvent)..where(
              (table) =>
                  table.source.equals(source) &
                  table.externalId.equals(externalId),
            ))
            .getSingleOrNull();
    return row == null ? null : toDomain(row);
  }

  Future<StressEvent?> find(int id) async {
    final row = await (db.select(
      db.stressEvent,
    )..where((table) => table.id.equals(id))).getSingleOrNull();
    return row == null ? null : toDomain(row);
  }

  static StressEvent toDomain(StressEventData row) => StressEvent(
    id: row.id,
    occurredAt: DateTime.fromMillisecondsSinceEpoch(row.occurredAt),
    source: row.source,
    externalId: row.externalId,
    notes: row.notes,
    endedAt: row.endedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(row.endedAt!),
    stressLevel: StressLevel.values.byName(row.stressLevel),
  );
}

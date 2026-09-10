import 'dart:io';

import 'package:diabeatthis/core/data_sources/stress_events/stress_event_repository.dart';
import 'package:diabeatthis/core/domain/model/stress_event.dart';
import 'package:diabeatthis/core/domain/model/stress_level.dart';
import 'package:diabeatthis/core/drift/database_impl.dart' hide StressEvent;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../helpers/basal_schema_columns.dart';

void main() {
  late DatabaseImpl db;
  late StressEventRepository repository;
  final time = DateTime(2026, 1, 1, 12);

  setUp(() {
    db = DatabaseImpl(NativeDatabase.memory());
    repository = StressEventRepository(db);
  });
  tearDown(() => db.close());

  test(
    'imports update by source identity while manual entries stay distinct',
    () async {
      for (final level in [StressLevel.low, StressLevel.high]) {
        await repository.save(
          StressEvent(
            source: 'watch',
            externalId: 'abc',
            occurredAt: time,
            stressLevel: level,
          ),
        );
        await repository.save(
          StressEvent(source: 'manual', occurredAt: time, stressLevel: level),
        );
      }
      final rows = await repository.between(time, time);
      expect(rows, hasLength(3));
      expect(
        rows.singleWhere((e) => e.source == 'watch').stressLevel,
        StressLevel.high,
      );
    },
  );

  test('stress can have a future end if it has already started', () async {
    final now = DateTime.now();
    final end = now.add(const Duration(hours: 1));
    final saved = await repository.save(
      StressEvent(
        source: 'manual',
        occurredAt: now.subtract(const Duration(minutes: 10)),
        endedAt: end,
        stressLevel: StressLevel.moderate,
      ),
    );
    expect(
      (await repository.find(saved.id!))!.endedAt!.millisecondsSinceEpoch,
      end.millisecondsSinceEpoch,
    );
  });

  test('future events are rejected', () async {
    await expectLater(
      repository.save(
        StressEvent(
          source: 'manual',
          occurredAt: DateTime.now().add(const Duration(days: 1)),
          stressLevel: StressLevel.low,
        ),
      ),
      throwsArgumentError,
    );
    expect(await repository.between(time, time), isEmpty);
  });

  test(
    'stress intervals overlap history windows and keep imported severity',
    () async {
      final start = time.subtract(const Duration(hours: 2));
      final end = time.add(const Duration(minutes: 30));
      final saved = await repository.save(
        StressEvent(
          source: 'watch',
          externalId: 'stress-1',
          occurredAt: start,
          endedAt: end,
          stressLevel: StressLevel.high,
        ),
      );
      final overlapping = await repository.between(
        time,
        time.add(const Duration(minutes: 10)),
      );
      expect(overlapping.single.id, saved.id);
      expect(overlapping.single.stressLevel, StressLevel.high);
      expect(overlapping.single.endedAt, end);
      expect(
        await repository.between(
          end.add(const Duration(seconds: 1)),
          end.add(const Duration(hours: 1)),
        ),
        isEmpty,
      );
      await expectLater(
        repository.save(
          StressEvent(
            source: 'manual',
            occurredAt: time,
            endedAt: start,
            stressLevel: StressLevel.low,
          ),
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'unchanged imports and already-recorded events do not write or trigger analysis refreshes',
    () async {
      final original = await repository.save(
        StressEvent(
          source: 'watch',
          externalId: 'stable',
          occurredAt: time,
          stressLevel: StressLevel.low,
        ),
      );
      final before =
          (await db.customSelect('SELECT total_changes() AS count').getSingle())
              .read<int>('count');
      await repository.save(
        StressEvent(
          source: 'watch',
          externalId: 'stable',
          occurredAt: time,
          stressLevel: StressLevel.low,
        ),
      );
      await repository.save(original);
      final after =
          (await db.customSelect('SELECT total_changes() AS count').getSingle())
              .read<int>('count');
      expect(after, before);
    },
  );

  for (final legacyTable in [true, false]) {
    test(
      'version 15 upgrade preserves stress with legacy table: $legacyTable',
      () async {
        final directory = await Directory.systemTemp.createTemp('stress-v15-');
        final file = File('${directory.path}/database.sqlite');
        final initial = DatabaseImpl(NativeDatabase(file));
        await StressEventRepository(initial).save(
          StressEvent(
            source: 'watch',
            externalId: 'existing',
            occurredAt: time,
            endedAt: time.add(const Duration(hours: 1)),
            stressLevel: StressLevel.high,
            notes: 'Existing stress',
          ),
        );
        await initial.close();
        final raw = sqlite3.open(file.path);
        if (legacyTable) {
          raw.execute('ALTER TABLE stress_event RENAME TO health_event');
          raw.execute(
            "ALTER TABLE health_event ADD COLUMN type TEXT NOT NULL DEFAULT 'stress'",
          );
          raw.execute('DROP INDEX idx_stress_event_occurred_at');
        }
        raw.execute(
          'ALTER TABLE glucose_reading RENAME TO glucose_reading_new',
        );
        raw.execute(
          "CREATE TABLE glucose_reading (source TEXT NOT NULL, external_id TEXT, created_at INTEGER NOT NULL PRIMARY KEY, received_at INTEGER NOT NULL DEFAULT 0, sgv INTEGER NOT NULL, direction TEXT)",
        );
        raw.execute(
          'INSERT INTO glucose_reading (source, external_id, created_at, received_at, sgv, direction) SELECT source, external_id, created_at, received_at, sgv, direction FROM glucose_reading_new',
        );
        raw.execute('DROP TABLE glucose_reading_new');
        raw.execute(
          'ALTER TABLE device_status DROP COLUMN aaps_predictions_json',
        );
        raw.execute(
          'ALTER TABLE device_status DROP COLUMN insulin_activity_at',
        );
        for (final column in basalSchemaColumns) {
          raw.execute('ALTER TABLE device_status DROP COLUMN $column');
        }
        raw.execute('PRAGMA user_version = 15');
        raw.dispose();
        final upgraded = DatabaseImpl(NativeDatabase(file));
        try {
          final store = StressEventRepository(upgraded);
          final rows = await store.between(
            time,
            time.add(const Duration(hours: 2)),
          );
          expect(rows.single.notes, 'Existing stress');
          expect(rows.single.stressLevel, StressLevel.high);
          await store.save(
            StressEvent(
              source: 'manual',
              occurredAt: time,
              endedAt: DateTime.now().add(const Duration(hours: 1)),
              stressLevel: StressLevel.low,
            ),
          );
          expect(
            await store.between(time, time.add(const Duration(hours: 2))),
            hasLength(2),
          );
        } finally {
          await upgraded.close();
          await directory.delete(recursive: true);
        }
      },
    );
  }

  test(
    'version 14 upgrade adds event storage without removing existing readings',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'health-event-migration-',
      );
      final file = File('${directory.path}/database.sqlite');
      final old = DatabaseImpl(NativeDatabase(file));
      await old
          .into(old.glucoseReading)
          .insert(
            GlucoseReadingCompanion.insert(
              source: 'cloud',
              createdAt: 1000,
              sgv: 123,
            ),
          );
      await old.close();
      final raw = sqlite3.open(file.path);
      raw.execute('DROP TABLE stress_event');
      raw.execute('ALTER TABLE glucose_reading RENAME TO glucose_reading_new');
      raw.execute(
        "CREATE TABLE glucose_reading (source TEXT NOT NULL, external_id TEXT, created_at INTEGER NOT NULL PRIMARY KEY, received_at INTEGER NOT NULL DEFAULT 0, sgv INTEGER NOT NULL, direction TEXT)",
      );
      raw.execute(
        'INSERT INTO glucose_reading (source, external_id, created_at, received_at, sgv, direction) SELECT source, external_id, created_at, received_at, sgv, direction FROM glucose_reading_new',
      );
      raw.execute('DROP TABLE glucose_reading_new');
      raw.execute(
        'ALTER TABLE device_status DROP COLUMN aaps_predictions_json',
      );
      raw.execute('ALTER TABLE device_status DROP COLUMN insulin_activity_at');
      for (final column in basalSchemaColumns) {
        raw.execute('ALTER TABLE device_status DROP COLUMN $column');
      }
      raw.execute('PRAGMA user_version = 14');
      raw.dispose();
      final upgraded = DatabaseImpl(NativeDatabase(file));
      try {
        final store = StressEventRepository(upgraded);
        await store.save(
          StressEvent(
            stressLevel: StressLevel.moderate,
            occurredAt: time,
            source: 'manual',
          ),
        );
        expect(await store.between(time, time), hasLength(1));
        expect(
          (await (upgraded.select(
            upgraded.glucoseReading,
          )..where((row) => row.type.equals('cgm'))).get()).single.sgv,
          123,
        );
        expect(
          await upgraded
              .customSelect(
                "SELECT name FROM sqlite_master WHERE type = 'index' AND name = 'idx_stress_event_occurred_at'",
              )
              .get(),
          hasLength(1),
        );
      } finally {
        await upgraded.close();
        await directory.delete(recursive: true);
      }
    },
  );
}

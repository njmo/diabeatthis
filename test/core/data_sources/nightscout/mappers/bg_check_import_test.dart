import 'dart:io';

import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/history/local_glucose_history_repository.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/history/local_treatments_history_repository.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/services/local_mirror_writer.dart';
import 'package:diabeatthis/core/data_sources/nightscout/helpers/treatments_factory.dart';
import 'package:diabeatthis/core/data_sources/nightscout/repository/nightscout_repository_impl.dart';
import 'package:diabeatthis/core/data_sources/nightscout/services/nightscout_service.dart';
import 'package:diabeatthis/core/domain/model/bg_check.dart';
import 'package:diabeatthis/core/drift/database_impl.dart'
    show DatabaseImpl, GlucoseReadingCompanion;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../../helpers/basal_schema_columns.dart';

Map<String, dynamic> meterPayload({
  String id = 'meter-1',
  Object value = 108,
  String units = 'mg/dl',
}) => {
  '_id': id,
  'eventType': 'BG Check',
  'created_at': '2026-01-01T12:06:00Z',
  'glucose': value,
  'units': units,
  'glucoseType': 'Finger',
  'notes': 'Before meal',
};

void main() {
  test(
    'all treatment queries request BG Check and parse the response',
    () async {
      final service = BgCheckService();
      final repository = NightscoutRepositoryImpl(
        nightscoutUrl: 'https://example.org',
        service: service,
      );
      final start = DateTime.utc(2026);
      for (final result in [
        await repository.fetchTreatmentsOnDay(start),
        await repository.fetchTreatmentsAfter(start),
        await repository.fetchTreatmentsBetween(
          start,
          start.add(const Duration(days: 1)),
        ),
      ]) {
        expect(result.whereType<BgCheck>().single.reading.sgv, 108);
      }
      expect(service.urls, hasLength(3));
      for (final url in service.urls) {
        expect(url.queryParameters.values, contains('BG Check'));
      }
    },
  );

  test(
    'normalizes mmol/l strings and skips malformed values without losing valid records',
    () {
      final events = TreatmentFactory().parseTreatments([
        meterPayload(value: '6.0', units: 'mmol/L'),
        meterPayload(value: 'NaN'),
        meterPayload(value: -1),
        meterPayload(units: 'unknown'),
        {...meterPayload(), 'created_at': 'invalid'},
        meterPayload(id: 'second'),
      ]).cast<BgCheck>();
      expect(events, hasLength(2));
      expect(events.first.reading.sgv, 108);
      expect(events.first.createdAt!.toUtc(), DateTime.utc(2026, 1, 1, 12, 6));
      expect(events.first.reading.type.name, 'finger');
    },
  );

  test(
    'reimport updates by identity, preserves simultaneous measurements and leaves CGM untouched',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      try {
        final writer = LocalMirrorWriter(db.localMirrorDao);
        final factory = TreatmentFactory();
        await db.localMirrorDao.upsertGlucoseReading(
          GlucoseReadingCompanion.insert(
            source: 'cloud',
            createdAt: DateTime.utc(2026, 1, 1, 12, 6).millisecondsSinceEpoch,
            sgv: 130,
          ),
        );
        for (final payload in [
          meterPayload(),
          meterPayload(value: 120),
          meterPayload(id: 'second'),
        ]) {
          await writer.mirrorTreatments(
            factory.parseTreatments([payload]),
            TreatmentsSource.cloud,
          );
        }
        final start = DateTime.utc(2026);
        final end = start.add(const Duration(days: 1));
        final events = await LocalTreatmentsHistoryRepository(
          db.localMirrorDao,
        ).fetchTreatmentsBetween(start, end);
        expect(events, hasLength(2));
        expect(
          events
              .cast<BgCheck>()
              .singleWhere((e) => e.reading.externalId == 'meter-1')
              .reading
              .sgv,
          120,
        );
        expect(
          (await LocalGlucoseHistoryRepository(
            db.localMirrorDao,
          ).fetchGlucoseBetween(start, end)).single.sgv,
          130,
        );
        expect(
          (await db.localMirrorDao.getRecentGlucoseReadings(10)).single.type,
          'cgm',
        );
        expect(await db.select(db.glucoseReading).get(), hasLength(3));
        await writer.mirrorTreatments(
          factory.parseTreatments([
            {...meterPayload(), 'isValid': false},
          ]),
          TreatmentsSource.cloud,
        );
        expect(
          await LocalTreatmentsHistoryRepository(
            db.localMirrorDao,
          ).fetchTreatmentsBetween(start, end),
          hasLength(1),
        );
      } finally {
        await db.close();
      }
    },
  );

  test(
    'version 16 migrates without losing glucose and supports BG Check persistence',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'bg-check-migration-',
      );
      final file = File('${directory.path}/db.sqlite');
      final initial = DatabaseImpl(NativeDatabase(file));
      await initial
          .into(initial.glucoseReading)
          .insert(
            GlucoseReadingCompanion.insert(
              source: 'cloud',
              createdAt: 1000,
              sgv: 123,
            ),
          );
      await initial.close();
      final raw = sqlite3.open(file.path);
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
      raw.execute('PRAGMA user_version = 16');
      raw.dispose();
      final upgraded = DatabaseImpl(NativeDatabase(file));
      try {
        await LocalMirrorWriter(upgraded.localMirrorDao).mirrorTreatments(
          TreatmentFactory().parseTreatments([meterPayload()]),
          TreatmentsSource.cloud,
        );
        expect(
          await (upgraded.select(
            upgraded.glucoseReading,
          )..where((row) => row.type.equals('finger'))).get(),
          hasLength(1),
        );
        expect(
          (await (upgraded.select(
            upgraded.glucoseReading,
          )..where((row) => row.type.equals('cgm'))).get()).single.sgv,
          123,
        );
      } finally {
        await upgraded.close();
        await directory.delete(recursive: true);
      }
    },
  );
}

class BgCheckService extends NightscoutService {
  BgCheckService() : super(nightscoutUrl: '');
  final List<Uri> urls = [];
  @override
  Future<dynamic> fetchNightscoutData(Uri url) async {
    urls.add(url);
    return [meterPayload()];
  }
}

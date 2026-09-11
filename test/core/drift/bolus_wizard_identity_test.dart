import 'dart:io';

import 'package:diabeatthis/core/data_sources/local_mirror/mappers/bolus_wizard_drift_mapper.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  BolusWizardCompanion event({
    String source = 'aaps',
    String? remoteId,
    double carbs = 20,
    int time = 1000,
  }) => BolusWizardCompanion.insert(
    source: source,
    createdAt: Value(time),
    nightscoutId: Value(remoteId),
    externalId: Value(remoteId),
    carbs: Value(carbs),
    insulin: const Value(2),
  );

  test(
    'remote enrichment and later AAPS writes retain the stable local and remote IDs',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      await db.localMirrorDao.upsertBolusWizard(event());
      final first = (await db.select(db.bolusWizard).get()).single;
      expect(first.localId, hasLength(32));
      for (final incoming in [
        event(source: 'cloud', remoteId: 'ns1'),
        event(),
        event(source: 'cloud', remoteId: 'ns1'),
      ]) {
        await db.localMirrorDao.upsertBolusWizard(incoming);
        final row = (await db.select(db.bolusWizard).get()).single;
        expect(row.localId, first.localId);
        expect(row.nightscoutId, 'ns1');
        expect(row.externalId, 'ns1');
        expect(row.toDomain().localId, first.localId);
      }
    },
  );

  test(
    'conflicting identity or calculator values never overwrite the existing event',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      await db.localMirrorDao.upsertBolusWizard(
        event(source: 'cloud', remoteId: 'ns1'),
      );
      for (final incoming in [
        event(source: 'cloud', remoteId: 'ns2'),
        event(carbs: 40),
      ]) {
        await expectLater(
          db.localMirrorDao.upsertBolusWizard(incoming),
          throwsStateError,
        );
      }
      final row = (await db.select(db.bolusWizard).get()).single;
      expect(row.nightscoutId, 'ns1');
      expect(row.carbs, 20);
      await db.localMirrorDao.upsertBolusWizard(
        event(source: 'cloud', remoteId: 'ns1', carbs: 25),
      );
      expect((await db.select(db.bolusWizard).get()).single.carbs, 25);
    },
  );

  test(
    'two successive 20g entries retain separate identities and concurrent enrichment is idempotent',
    () async {
      final db = DatabaseImpl(NativeDatabase.memory());
      addTearDown(db.close);
      await db.localMirrorDao.upsertBolusWizard(event());
      await Future.wait([
        db.localMirrorDao.upsertBolusWizard(
          event(source: 'cloud', remoteId: 'ns1'),
        ),
        db.localMirrorDao.upsertBolusWizard(
          event(source: 'cloud', remoteId: 'ns1'),
        ),
      ]);
      await db.localMirrorDao.upsertBolusWizard(event(time: 1801000));
      final rows = await db.select(db.bolusWizard).get();
      expect(rows, hasLength(2));
      expect(rows.map((row) => row.localId).toSet(), hasLength(2));
    },
  );

  test(
    'version 24 migration preserves every field and gives each old wizard a persistent ID',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'wizard-identity-',
      );
      final file = File('${directory.path}/db.sqlite');
      var db = DatabaseImpl(NativeDatabase(file));
      try {
        await db.customSelect('SELECT 1 FROM bolus_wizard').get();
        await db.customStatement('DROP TRIGGER remove_local_only_wizard_links');
        await db.customStatement('DROP TABLE meal_wizard_link');
        await db.customStatement('DROP TABLE bolus_wizard');
        final schema = await File(
          'test/core/drift/fixtures/bolus_wizard_v24.sql',
        ).readAsString();
        for (final statement
            in schema.split(';').where((s) => s.trim().isNotEmpty)) {
          await db.customStatement(statement);
        }
        await db.customStatement(
          "INSERT INTO bolus_wizard(source,created_at,nightscout_id,carbs,insulin,calculator_id,calculator_note) VALUES ('cloud',1000,'ns1',20,2,17,'original'),('aaps',2000,NULL,30,3,18,'second')",
        );
        final before = await db
            .customSelect('SELECT * FROM bolus_wizard ORDER BY created_at')
            .get();
        await db.customStatement('PRAGMA user_version = 24');
        await db.close();
        db = DatabaseImpl(NativeDatabase(file));
        final after = await db
            .customSelect('SELECT * FROM bolus_wizard ORDER BY created_at')
            .get();
        for (var i = 0; i < before.length; i++) {
          for (final field in before[i].data.entries) {
            expect(after[i].data[field.key], field.value, reason: field.key);
          }
        }
        expect(
          await db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
        final ids = after.map((row) => row.read<String>('local_id')).toList();
        expect(ids.toSet(), hasLength(2));
        await db.close();
        db = DatabaseImpl(NativeDatabase(file));
        expect(
          (await db.select(db.bolusWizard).get()).map((row) => row.localId),
          ids,
        );
      } finally {
        await db.close();
        await directory.delete(recursive: true);
      }
    },
  );
}

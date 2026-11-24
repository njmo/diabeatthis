import 'dart:io';

import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:drift/drift.dart' show MigrationStrategy, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _Version53Database extends DatabaseImpl {
  _Version53Database(super.executor, {required this.missingComponent});

  final bool missingComponent;

  @override
  int get schemaVersion => 53;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      if (missingComponent) {
        await customStatement(
          'ALTER TABLE bolus_wizard DROP COLUMN carbohydrate_component',
        );
      }
    },
  );
}

void main() {
  for (final missingComponent in [true, false]) {
    test(
      'upgrades a version 53 mirror with missingComponent=$missingComponent',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'wizard-migration-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final file = File('${directory.path}/database.sqlite');
        final old = _Version53Database(
          NativeDatabase(file),
          missingComponent: missingComponent,
        );
        const at = 1795506553648;
        await old.customStatement(
          "INSERT INTO bolus_wizard (local_id, source, created_at, carbs, insulin) VALUES ('existing', 'aaps', ?, 17, 1.75)",
          [at],
        );
        await old.close();

        final db = DatabaseImpl(NativeDatabase(file));
        addTearDown(db.close);
        final before = await db.select(db.bolusWizard).getSingle();
        expect(before.localId, 'existing');
        expect(before.carbs, 17);

        final updated = await db.localMirrorDao.upsertBolusWizard(
          BolusWizardCompanion.insert(
            source: 'aaps',
            createdAt: const Value(at),
            nightscoutId: const Value('nightscout-id'),
            carbs: const Value(17),
            insulin: const Value(1.75),
          ),
        );
        expect(updated.localId, 'existing');
        expect(updated.nightscoutId, 'nightscout-id');
        expect(updated.insulin, 1.75);
        expect(await db.select(db.bolusWizard).get(), hasLength(1));
      },
    );
  }
}

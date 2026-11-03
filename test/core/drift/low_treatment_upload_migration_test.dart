import 'dart:io';

import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:drift/drift.dart' show MigrationStrategy;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class Version42LowTreatmentDatabase extends DatabaseImpl {
  Version42LowTreatmentDatabase(super.executor);
  @override
  int get schemaVersion => 42;
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement('DROP TABLE low_treatment_upload');
    },
  );
}

void main() {
  test(
    'version 42 upgrade adds the delivery queue and retains existing meals',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'low-treatment-upload-migration-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/database.sqlite');
      final old = Version42LowTreatmentDatabase(NativeDatabase(file));
      await old
          .into(old.meal)
          .insert(MealCompanion.insert(name: 'Existing meal', plannedAt: 1000));
      await old.close();
      final db = DatabaseImpl(NativeDatabase(file));
      addTearDown(db.close);
      expect((await db.select(db.meal).get()).single.name, 'Existing meal');
      expect(await db.select(db.lowTreatmentUpload).get(), isEmpty);
    },
  );
}

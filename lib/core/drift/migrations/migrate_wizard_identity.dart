import 'package:drift/drift.dart';

import '../database_impl.dart';

Future<void> migrateWizardIdentity(DatabaseImpl db, Migrator migrator) async {
  final columns = await db
      .customSelect('PRAGMA table_info(bolus_wizard)')
      .get();
  if (!columns.any((column) => column.read<String>('name') == 'local_id')) {
    await migrator.alterTable(
      // ignore: experimental_member_use
      TableMigration(
        db.bolusWizard,
        newColumns: [db.bolusWizard.localId, db.bolusWizard.remoteSource],
      ),
    );
  }
  final index = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'index' AND name = ?",
        variables: [
          Variable.withString(db.idxBolusWizardRemoteIdentity.entityName),
        ],
      )
      .get();
  if (index.isEmpty) {
    await migrator.createIndex(db.idxBolusWizardRemoteIdentity);
  }
  final links = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'meal_wizard_link'",
      )
      .get();
  if (links.isEmpty) await migrator.createTable(db.mealWizardLink);
  await db.customStatement(
    'DROP TRIGGER IF EXISTS remove_local_only_wizard_links',
  );
  await migrator.createTrigger(db.removeLocalOnlyWizardLinks);
}

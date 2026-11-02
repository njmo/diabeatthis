import 'package:drift/drift.dart';

import '../database_impl.dart';

Future<void> migrateMealAddOnBolusContext(
  DatabaseImpl db,
  Migrator migrator,
) async {
  final columns = await db.customSelect('PRAGMA table_info(meal)').get();
  if (!columns.any(
    (row) => row.read<String>('name') == 'add_on_bolus_context',
  )) {
    await migrator.addColumn(db.meal, db.meal.addOnBolusContext);
  }
}

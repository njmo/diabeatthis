import 'package:drift/drift.dart';

import '../database_impl.dart';

Future<void> migrateMealConsumptionConfirmation(
  DatabaseImpl db,
  Migrator migrator,
) async {
  final columns = await db.customSelect('PRAGMA table_info(meal)').get();
  if (!columns.any(
    (row) => row.read<String>('name') == 'consumption_confirmed_ended_at',
  )) {
    await migrator.addColumn(db.meal, db.meal.consumptionConfirmedEndedAt);
  }
}

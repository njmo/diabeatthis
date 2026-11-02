import 'package:drift/drift.dart';

import '../database_impl.dart';

Future<void> migrateMealCompletionDecision(
  DatabaseImpl db,
  Migrator migrator,
) async {
  final columns = await db.customSelect('PRAGMA table_info(meal)').get();
  if (!columns.any(
    (row) => row.read<String>('name') == 'completion_decision',
  )) {
    await migrator.addColumn(db.meal, db.meal.completionDecision);
  }
}

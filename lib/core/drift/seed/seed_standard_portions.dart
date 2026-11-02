import '../../../common/portions/standard_portion_names.dart';
import '../database_impl.dart';

/// Adds a reusable name only. An ingredient's weight must still be defined.
Future<void> seedStandardPortions(DatabaseImpl database) async {
  await database.customStatement(
    '''INSERT INTO portion (name, unit_hint)
       SELECT ?, ?
       WHERE NOT EXISTS (
         SELECT 1 FROM portion WHERE lower(trim(name)) IN (?, ?)
       )''',
    [
      standardPiecePortionName,
      standardPortionWeightUnit,
      ...piecePortionAliases,
    ],
  );
}

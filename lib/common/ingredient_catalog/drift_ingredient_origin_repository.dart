import 'package:drift/drift.dart';

import '../../core/drift/database_impl.dart';
import 'ingredient_identity.dart';
import 'ingredient_origin_repository.dart';

class DriftIngredientOriginRepository implements IngredientOriginRepository {
  const DriftIngredientOriginRepository(this.db);
  final DatabaseImpl db;
  @override
  Future<IngredientOriginSnapshot?> read(int localIngredientId) async {
    final row = await db
        .customSelect(
          'SELECT * FROM ingredient_origin WHERE ingredient_id = ?',
          variables: [Variable(localIngredientId)],
        )
        .getSingleOrNull();
    if (row == null) return null;
    return IngredientOriginSnapshot(
      localIngredientId: localIngredientId,
      identity: IngredientIdentity.fromJson({
        'source': row.read<String>('source'),
        'sourceId': row.read<String>('source_id'),
      }),
      nutritionConfidenceAssessed:
          row.read<String>('confidence_origin') == 'user_assessed',
      creationMethod: row.read<String>('creation_method'),
      sourceRevision: row.readNullable<String>('source_revision'),
      englishName: row.readNullable<String>('english_name'),
      displayLanguageCode: row.readNullable<String>('display_language_code'),
      sourceSnapshotJson: row.readNullable<String>('source_snapshot_json'),
      referenceScope: row.readNullable<String>('reference_scope'),
      provenanceJson: row.readNullable<String>('provenance_json'),
      copiedFromJson: row.readNullable<String>('copied_from_json'),
    );
  }

  @override
  Future<void> markConfidenceAssessed(int localIngredientId) async {
    final changed = await db.customUpdate(
      "UPDATE ingredient_origin SET confidence_origin = 'user_assessed' WHERE ingredient_id = ? AND source = 'local'",
      variables: [Variable(localIngredientId)],
    );
    if (changed != 1) {
      throw StateError(
        'Confidence assessment requires an existing local ingredient',
      );
    }
  }
}

import '../../core/drift/database_impl.dart';
import 'ingredient_identity.dart';
import 'ingredient_match_score.dart';
import 'ingredient_search_item.dart';
import 'ingredient_search_normalizer.dart';
import 'local_ingredient_search_repository.dart';

class DriftLocalIngredientSearchRepository
    implements LocalIngredientSearchRepository {
  const DriftLocalIngredientSearchRepository(this.db);
  final DatabaseImpl db;

  @override
  Future<List<IngredientSearchItem>> search(
    String query, {
    int limit = 20,
  }) async {
    // Local data is already on this device. Normalize both sides so Polish
    // diacritics work without downloading any remote catalog records.
    final tokens = ingredientSearchTerms(query).toList();
    final rows = await db
        .customSelect(
          '''
SELECT i.id, i.name, i.brand, i.icon_asset_path, i.is_reference, o.source, o.source_id,
 o.english_name, o.display_language_code, o.source_revision, o.confidence_origin
FROM ingredient i JOIN ingredient_origin o ON o.ingredient_id = i.id
ORDER BY i.name COLLATE NOCASE, i.id
''',
          readsFrom: {db.ingredient},
        )
        .get();
    rows.sort(
      (a, b) =>
          ingredientMatchScore(
            query,
            '${b.read<String>('name')} ${b.readNullable<String>('english_name') ?? ''}',
          ).compareTo(
            ingredientMatchScore(
              query,
              '${a.read<String>('name')} ${a.readNullable<String>('english_name') ?? ''}',
            ),
          ),
    );
    return rows
        .where((row) {
          final haystack = normalizeIngredientSearch(
            '${row.read<String>('name')} ${row.readNullable<String>('brand') ?? ''} ${row.readNullable<String>('english_name') ?? ''}',
          );
          return tokens.isEmpty || ingredientMatchScore(query, haystack) >= .5;
        })
        .take(limit.clamp(0, 100))
        .map(
          (row) => IngredientSearchItem(
            identity: IngredientIdentity.fromJson({
              'source': row.read<String>('source'),
              'sourceId': row.read<String>('source_id'),
            }),
            name: row.read<String>('name'),
            englishName: row.readNullable<String>('english_name'),
            details: row.readNullable<String>('brand') ?? '',
            languageCode:
                row.readNullable<String>('display_language_code') ?? 'en',
            iconAssetPath: row.readNullable<String>('icon_asset_path'),
            localIngredientId: row.read<int>('id'),
            isReference: row.read<int>('is_reference') == 1,
            sourceRevision: row.readNullable<String>('source_revision'),
            nutritionConfidenceAssessed:
                row.read<String>('confidence_origin') == 'user_assessed',
          ),
        )
        .toList(growable: false);
  }
}

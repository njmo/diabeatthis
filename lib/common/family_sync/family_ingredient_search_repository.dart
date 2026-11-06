import '../ingredient_catalog/ingredient_identity.dart';
import '../ingredient_catalog/ingredient_match_score.dart';
import '../ingredient_catalog/ingredient_search_item.dart';
import '../ingredient_catalog/local_ingredient_search_repository.dart';

/// Uses the child's cloud projection, never the caregiver's patient tables.
class FamilyIngredientSearchRepository
    implements LocalIngredientSearchRepository {
  const FamilyIngredientSearchRepository(this.rows);
  final List<Map<String, dynamic>> rows;
  @override
  Future<List<IngredientSearchItem>> search(
    String query, {
    int limit = 20,
  }) async {
    final result = <IngredientSearchItem>[];
    for (final row in rows.where(
      (r) => r['kind'] == 'ingredients' && r['deleted'] != true,
    )) {
      final p = row['payload'] as Map;
      final origin =
          rows
                  .where(
                    (r) =>
                        r['kind'] == 'ingredientOrigins' &&
                        r['deleted'] != true &&
                        (r['payload'] as Map)['ingredient_id'] == p['id'],
                  )
                  .firstOrNull?['payload']
              as Map?;
      if (query.trim().isNotEmpty &&
          ingredientMatchScore(
                query,
                '${p['name']} ${p['brand'] ?? ''} ${origin?['english_name'] ?? ''}',
              ) <
              .5) {
        continue;
      }
      result.add(
        IngredientSearchItem(
          identity: IngredientIdentity.fromJson({
            'source': origin?['source'] ?? 'local',
            'sourceId': origin?['source_id'] ?? '${p['id']}',
          }),
          name: p['name'] as String,
          localIngredientId: p['id'] as int,
          englishName: origin?['english_name'] as String?,
          sourceRevision: origin?['source_revision'] as String?,
          isReference: p['is_reference'] == 1,
          details: p['brand'] as String? ?? '',
        ),
      );
    }
    result.sort(
      (a, b) => ingredientMatchScore(
        query,
        b.name,
      ).compareTo(ingredientMatchScore(query, a.name)),
    );
    return result.take(limit).toList();
  }
}

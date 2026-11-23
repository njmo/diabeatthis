import '../../../core/domain/model/ingredient.dart';
import '../../../features/meal_photo/data/meal_photo_local_ingredient_reader.dart';
import '../../ingredient_catalog/ingredient_search_item.dart';
import '../../ingredient_catalog/local_ingredient_search_repository.dart';
import '../child_ingredient_search_repository.dart';
import '../presentation/models/family_ingredient_view.dart';

class FamilyPhotoIngredientReader
    implements MealPhotoLocalIngredientReader, LocalIngredientSearchRepository {
  FamilyPhotoIngredientReader(this.child, this.sourceId);

  final ChildIngredientSearchRepository child;
  final String sourceId;
  final _reviewIngredients = <int, Ingredient>{};

  @override
  Future<List<IngredientSearchItem>> search(
    String query, {
    int limit = 20,
  }) async {
    final matches = (await child.search(query, limit: limit))
        .whereType<ChildIngredientSearchItem>()
        .where((match) => !match.isReference);
    return [
      for (final match in matches)
        ChildIngredientSearchItem(
          _reviewIngredients.putIfAbsent(
            match.ingredient.id,
            () => match.ingredient,
          ),
        ),
    ];
  }

  @override
  Future<Ingredient> get(int id) async {
    if (!child.isCurrent()) throw StateError('The selected child changed');
    return _reviewIngredients[id]!;
  }

  Future<List<Map<String, dynamic>>> baseRows(Set<int> selectedIds) =>
      Future.wait(
        selectedIds.map((id) async {
          final reviewed = await get(id);
          final snapshot = await child.quickTreatmentEditorRows(
            ingredientId: id,
          );
          if (snapshot.sourceId != sourceId) {
            throw StateError('The selected child source changed');
          }
          final row = snapshot.rows.singleWhere(
            (row) =>
                row['kind'] == 'ingredients' &&
                row['id'] == '$id' &&
                row['deleted'] != true,
          );
          if (familyIngredientView(row) != reviewed) {
            throw StateError('The selected ingredient changed during review');
          }
          return row;
        }),
      );
}

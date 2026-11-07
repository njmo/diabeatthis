import '../../../core/domain/model/ingredient.dart';
import '../../../features/meal_photo/data/meal_photo_local_ingredient_reader.dart';
import '../presentation/models/family_ingredient_view.dart';

class FamilyPhotoIngredientReader implements MealPhotoLocalIngredientReader {
  const FamilyPhotoIngredientReader(this.rows);
  final List<Map<String, dynamic>> rows;
  @override
  Future<Ingredient> get(int id) async => familyIngredientView(
    rows.singleWhere(
      (r) =>
          r['kind'] == 'ingredients' &&
          r['deleted'] != true &&
          r['id'] == '$id',
    ),
  );
}

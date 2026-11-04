import '../../../core/domain/model/ingredient.dart' as domain;
import '../../../core/drift/database_impl.dart';
import '../../../core/drift/mappers/ingredient_drift_mapper.dart';
import 'meal_photo_local_ingredient_reader.dart';

class DriftMealPhotoLocalIngredientReader
    implements MealPhotoLocalIngredientReader {
  const DriftMealPhotoLocalIngredientReader(this.db);
  final DatabaseImpl db;
  @override
  Future<domain.Ingredient> get(int id) async =>
      (await db.ingredientDao.getIngredientById(id)).toDomain();
}

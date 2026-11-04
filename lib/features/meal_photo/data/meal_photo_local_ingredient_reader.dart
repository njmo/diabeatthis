import '../../../core/domain/model/ingredient.dart';

abstract interface class MealPhotoLocalIngredientReader {
  Future<Ingredient> get(int id);
}

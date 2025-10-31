import 'package:drift/drift.dart';
import '../database_impl.dart';

part 'ingredient_dao.g.dart';

@DriftAccessor(include: {'../schemas/tables/ingredient.drift'})
class IngredientDao extends DatabaseAccessor<DatabaseImpl> with _$IngredientDaoMixin {
  IngredientDao(super.db);
}
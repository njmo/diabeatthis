import 'package:diabeatthis/core/drift/dao/ingredient_dao.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scripted_read.dart';

class ScriptedIngredientDetailsIngredientDao extends Fake
    implements IngredientDao {
  final ScriptedRead<IngredientData> ingredientRead;
  final ScriptedRead<List<IngredientStatusHistoryData>> history;
  ScriptedIngredientDetailsIngredientDao(this.ingredientRead, this.history);
  @override
  Future<IngredientData> getIngredientById(int id) => ingredientRead([id]);
  @override
  Future<List<IngredientStatusHistoryData>> getIngredientStatusHistory(
    int id,
  ) => history([id]);
}

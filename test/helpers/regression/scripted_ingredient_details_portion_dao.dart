import 'package:diabeatthis/core/drift/dao/portion_dao.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scripted_read.dart';

class ScriptedIngredientDetailsPortionDao extends Fake implements PortionDao {
  final ScriptedRead<List<PortionData>> portions;
  final ScriptedRead<double?> grams;
  ScriptedIngredientDetailsPortionDao(this.portions, this.grams);
  @override
  Future<List<PortionData>> getPortionsForIngredientId(int id) =>
      portions([id]);
  @override
  Future<double?> getGramsPerPortion(int ingredientId, int portionId) =>
      grams([ingredientId, portionId]);
}

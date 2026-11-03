import 'package:diabeatthis/features/ingredients/data/domain/use_cases/load_ingredient_details_use_case.dart';
import 'package:diabeatthis/features/ingredients/data/models/ingredient_details_data.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scripted_read.dart';

class ScriptedLoadIngredientDetailsUseCase extends Fake
    implements LoadIngredientDetailsUseCase {
  final ScriptedRead<IngredientDetailsData> reads;
  ScriptedLoadIngredientDetailsUseCase(this.reads);

  @override
  Future<IngredientDetailsData> call(int ingredientId) => reads([ingredientId]);
}

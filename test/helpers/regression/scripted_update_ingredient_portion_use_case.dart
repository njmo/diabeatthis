import 'package:diabeatthis/features/ingredients/data/domain/use_cases/update_ingredient_details_use_case.dart';
import 'package:flutter_test/flutter_test.dart';

import 'scripted_read.dart';

class ScriptedUpdateIngredientPortionUseCase extends Fake
    implements UpdateIngredientDetailsUseCase {
  final ScriptedRead<void> writes;
  ScriptedUpdateIngredientPortionUseCase(this.writes);

  @override
  Future<void> updatePortionAmount({
    required int ingredientId,
    required int portionId,
    required double gramsPerPortion,
  }) => writes([ingredientId, portionId, gramsPerPortion]);
}

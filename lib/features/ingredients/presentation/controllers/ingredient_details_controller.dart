import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/domain/use_cases/load_ingredient_details_use_case.dart';
import '../models/ingredient_page_state.dart';

part 'ingredient_details_controller.g.dart';

@riverpod
class IngredientDetailsControllerNotifier extends _$IngredientDetailsControllerNotifier {
  @override
  Future<IngredientPageState> build(int ingredientId) async {
    final useCase = ref.read(loadIngredientDetailsUseCaseProvider);
    final data = await useCase.call(ingredientId);

    return IngredientPageState(data: data);
  }
}

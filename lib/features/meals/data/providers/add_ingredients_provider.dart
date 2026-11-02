import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../presentation/controllers/add_ingredient_flow_controller.dart';

export '../../presentation/controllers/add_ingredient_flow_controller.dart';
export 'ingredient_flow_form_providers.dart';

final addMealIngredientStageProvider =
    NotifierProvider.autoDispose<
      AddMealIngredientStageNotifier,
      AddMealIngredientStage
    >(AddMealIngredientStageNotifier.new);

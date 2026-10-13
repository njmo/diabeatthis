import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/meal_ai_provider.dart';
import '../../domain/models/meal_dml_document.dart';
import '../../domain/serialization/meal_dml_serializer.dart';

final mealAiInputProvider = AsyncNotifierProvider.autoDispose
    .family<MealAiInputController, MealDmlDocument, int>(
      MealAiInputController.new,
    );

class MealAiInputController extends AsyncNotifier<MealDmlDocument> {
  final int mealId;
  MealAiInputController(this.mealId);
  @override
  Future<MealDmlDocument> build() async {
    final buildContext = ref.watch(buildMealAiContextUseCaseProvider);
    return serializeMealDml(await buildContext(mealId));
  }

  void retry() {
    if (state.hasError) ref.invalidateSelf();
  }
}

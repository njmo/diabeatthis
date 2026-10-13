import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/meal_ai_provider.dart';
import '../../domain/models/meal_dml_document.dart';
import 'meal_ai_input_controller.dart';
import 'meal_ai_state.dart';

typedef MealAiRequest = ({int mealId, String language});
final mealAiControllerProvider = NotifierProvider.autoDispose
    .family<MealAiController, MealAiState, MealAiRequest>(MealAiController.new);

class MealAiController extends Notifier<MealAiState> {
  final MealAiRequest request;
  MealAiController(this.request);
  ProviderSubscription<AsyncValue<MealDmlDocument>>? _inputSubscription;
  @override
  MealAiState build() => const MealAiState();
  Future<void> generate() async {
    if (state.busy) return;
    final previous = state.draft;
    state = MealAiState(draft: previous, generating: true);
    try {
      _inputSubscription ??= ref.listen(
        mealAiInputProvider(request.mealId),
        (_, _) {},
      );
      final input = await ref.read(mealAiInputProvider(request.mealId).future);
      if (!ref.mounted) return;
      final draft = await ref.read(analyzeMealAiUseCaseProvider)(
        input,
        language: request.language,
      );
      if (ref.mounted) state = MealAiState(draft: draft);
    } catch (error) {
      if (ref.mounted) state = MealAiState(draft: previous, error: error);
    }
  }

  void discard() {
    if (!state.busy) state = const MealAiState();
  }

  Future<void> accept() async {
    final draft = state.draft;
    if (state.busy || draft == null) return;
    state = MealAiState(draft: draft, saving: true);
    try {
      await ref.read(acceptMealAiUseCaseProvider)(draft);
      if (!ref.mounted) return;
      ref.invalidate(acceptedMealAiProvider(request.mealId));
      state = const MealAiState();
    } catch (error) {
      if (ref.mounted) state = MealAiState(draft: draft, saveError: error);
    }
  }
}

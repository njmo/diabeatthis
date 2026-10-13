import '../models/meal_ai_draft.dart';

class AcceptMealAiUseCase {
  final Future<void> Function(AcceptedMealAi) save;
  final DateTime Function() now;
  const AcceptMealAiUseCase({required this.save, required this.now});
  Future<void> call(MealAiDraft draft) =>
      save(AcceptedMealAi(draft: draft, acceptedAt: now()));
}

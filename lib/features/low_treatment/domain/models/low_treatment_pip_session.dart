/// Stable across UI and foreground engines and foreground restarts.
class LowTreatmentPipSession {
  static const carbsAction = 'lowTreatment.carbs';

  static String forMeal(int mealId) => 'lowTreatment:$mealId';
}

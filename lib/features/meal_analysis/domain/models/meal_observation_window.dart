/// Existing observation policy, not a physiological absorption cutoff.
class MealObservationWindow {
  static Duration forWbtKcal(double wbtKcal) =>
      wbtKcal > 100 ? const Duration(hours: 3) : const Duration(minutes: 90);
}

class MealActivityWindows {
  const MealActivityWindows({this.pastMinutes = 120, this.futureMinutes = 60});

  final int pastMinutes;
  final int futureMinutes;

  bool get isValid =>
      pastMinutes >= 0 &&
      pastMinutes <= 1440 &&
      futureMinutes >= 0 &&
      futureMinutes <= 1440;
}

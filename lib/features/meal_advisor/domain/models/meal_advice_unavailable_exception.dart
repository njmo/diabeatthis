class MealAdviceUnavailableException implements Exception {
  const MealAdviceUnavailableException();

  @override
  String toString() =>
      'Brak aktualnych odczytów CGM lub kompletnych danych IOB/COB. Wybierz decyzję ręcznie.';
}

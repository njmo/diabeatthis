class MealAddOnGuidance {
  const MealAddOnGuidance({required this.title, required this.message});

  final String title;
  final String message;
}

String mealStatusAfterAddOn(String? status) {
  switch (status) {
    case 'eating-then-bolus':
      return 'eating-then-bolus';
    case 'bolused-eating':
      return 'bolused-eating';
    case 'waited-eating':
      return 'waited-eating';
    default:
      return 'eating-extra';
  }
}

MealAddOnGuidance buildMealAddOnGuidance({
  required String? currentMealStatus,
  required int addedCarbs,
  required int? totalCarbsForBolus,
}) {
  if (currentMealStatus == 'eating-then-bolus' && totalCarbsForBolus != null) {
    return MealAddOnGuidance(
      title: 'Do AAPS: ${totalCarbsForBolus}g węglowodanów',
      message:
          'Podaj gramy na to, co zostało zjedzone: plan posiłku razem z dokładką. Dokładka dodała około ${addedCarbs}g, więc w AAPS wpisz łącznie ${totalCarbsForBolus}g.',
    );
  }

  return MealAddOnGuidance(
    title: 'Dokładka: +${addedCarbs}g węglowodanów',
    message:
        'Wpisz +${addedCarbs}g w AAPS jako dodatkowe węglowodany. Posiłek zostaje w trakcie jedzenia.',
  );
}

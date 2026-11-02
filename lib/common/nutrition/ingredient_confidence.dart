/// Confidence of one planned ingredient, combining its nutrition data and amount.
/// The portion count affects nutrition totals, but not these independent inputs.
double combineIngredientConfidence({
  required double nutritionConfidence,
  required double quantityConfidence,
}) => nutritionConfidence * quantityConfidence;

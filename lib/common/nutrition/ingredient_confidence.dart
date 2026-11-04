import 'dart:math' as math;

/// Combines nutrition and amount confidence using their geometric mean.
/// Equal input assessments retain their level, regardless of portion count.
double combineIngredientConfidence({
  required double nutritionConfidence,
  required double quantityConfidence,
}) => math.sqrt(nutritionConfidence * quantityConfidence);

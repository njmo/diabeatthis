import 'confidence_level.dart';

/// An unassessed catalog record starts at medium, never at user-verified certainty.
double catalogNutritionConfidence(double? value, {required bool assessed}) =>
    assessed ? (value ?? 0) : ConfidenceLevel.medium.toDouble01();

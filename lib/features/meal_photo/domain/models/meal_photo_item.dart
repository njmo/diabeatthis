import 'meal_photo_candidate.dart';
import 'meal_photo_nutrition.dart';

enum MealPhotoItemKind { matched, needsAssignment, proposedReference }

enum MealPhotoReferenceScope { component, wholeMeal }

class MealPhotoItem {
  const MealPhotoItem({
    required this.id,
    required this.name,
    required this.searchQuery,
    required this.kind,
    required this.recognitionConfidence,
    required this.quantityConfidence,
    required this.nutritionConfidence,
    this.usdaFoodName,
    this.estimatedWeightGrams,
    this.candidate,
    this.referenceNutrition,
    this.referenceScope = MealPhotoReferenceScope.component,
    this.reason = '',
  });
  final String id;
  final String name;
  final String searchQuery;
  final String? usdaFoodName;
  final MealPhotoItemKind kind;
  final double recognitionConfidence;
  final double quantityConfidence;
  final double nutritionConfidence;
  final double? estimatedWeightGrams;
  final MealPhotoCandidate? candidate;
  final MealPhotoNutrition? referenceNutrition;
  final MealPhotoReferenceScope referenceScope;
  final String reason;
}

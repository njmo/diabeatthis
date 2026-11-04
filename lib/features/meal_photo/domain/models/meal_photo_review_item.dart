import 'meal_photo_candidate.dart';
import 'meal_photo_item.dart';
import 'meal_photo_nutrition.dart';

enum MealPhotoSelectionMethod { automatic, manual }

class MealPhotoReviewItem {
  const MealPhotoReviewItem({
    required this.proposal,
    required this.weightGrams,
    required this.quantityConfidence,
    required this.nutritionConfidence,
    this.product,
    this.referenceAccepted = false,
    this.reviewed = false,
    this.manualReferenceNutrition,
    this.suggestedProduct,
    this.manualReferenceConfidence,
    this.manualReferenceName,
    this.selectionMethod = MealPhotoSelectionMethod.automatic,
  });
  factory MealPhotoReviewItem.fromProposal(MealPhotoItem item) =>
      MealPhotoReviewItem(
        proposal: item,
        weightGrams: item.estimatedWeightGrams,
        quantityConfidence: item.quantityConfidence,
        nutritionConfidence: item.candidate == null
            ? item.nutritionConfidence
            : item.candidate!.effectiveNutritionConfidence,
        product: item.candidate,
      );
  final MealPhotoItem proposal;
  final MealPhotoSelectionMethod selectionMethod;

  /// A manual product correction takes precedence over the original AI label.
  String get displayName =>
      product != null && selectionMethod == MealPhotoSelectionMethod.manual
      ? product!.name
      : manualReferenceName ?? proposal.name;
  final double? weightGrams;
  final double quantityConfidence;
  final double nutritionConfidence;
  final MealPhotoCandidate? product;
  final MealPhotoCandidate? suggestedProduct;
  final double? manualReferenceConfidence;
  final String? manualReferenceName;
  double get referenceNutritionConfidence =>
      manualReferenceConfidence ?? proposal.nutritionConfidence;
  MealPhotoNutrition? get editableReferenceNutrition =>
      referenceNutrition ??
      (validWeight
          ? (product ?? suggestedProduct)?.nutritionPer100g.scaled(
              weightGrams! / 100,
            )
          : null);
  final bool referenceAccepted;
  final bool reviewed;
  final MealPhotoNutrition? manualReferenceNutrition;
  MealPhotoNutrition? get referenceNutrition =>
      manualReferenceNutrition ?? proposal.referenceNutrition;
  bool get assigned =>
      product != null || (referenceAccepted && referenceNutrition != null);
  bool get validWeight =>
      weightGrams != null && weightGrams!.isFinite && weightGrams! > 0;
  MealPhotoNutrition? get nutritionForPortion => product != null && validWeight
      ? product!.nutritionPer100g.scaled(weightGrams! / 100)
      : referenceAccepted
      ? referenceNutrition
      : null;
  MealPhotoReviewItem assign(
    MealPhotoCandidate value, {
    MealPhotoSelectionMethod method = MealPhotoSelectionMethod.manual,
  }) => MealPhotoReviewItem(
    proposal: proposal,
    selectionMethod: method,
    weightGrams: weightGrams,
    quantityConfidence: quantityConfidence,
    nutritionConfidence: value.effectiveNutritionConfidence,
    product: value,
    suggestedProduct: value,
    manualReferenceNutrition: manualReferenceNutrition,
    manualReferenceName: manualReferenceName,
    manualReferenceConfidence: manualReferenceConfidence,
  );
  MealPhotoReviewItem acceptReference({
    MealPhotoSelectionMethod method = MealPhotoSelectionMethod.manual,
  }) {
    if (referenceNutrition == null) {
      throw StateError('No reference nutrition proposed');
    }
    return MealPhotoReviewItem(
      proposal: proposal,
      selectionMethod: method,
      weightGrams: weightGrams,
      quantityConfidence: quantityConfidence,
      nutritionConfidence: referenceNutritionConfidence,
      referenceAccepted: true,
      suggestedProduct: product ?? suggestedProduct,
      manualReferenceNutrition: manualReferenceNutrition,
      manualReferenceName: manualReferenceName,
      manualReferenceConfidence: manualReferenceConfidence,
    );
  }

  MealPhotoReviewItem withManualReference(
    MealPhotoNutrition nutrition, {
    double confidence = .3,
  }) {
    nutrition.validate();
    return MealPhotoReviewItem(
      proposal: proposal,
      selectionMethod: MealPhotoSelectionMethod.manual,
      weightGrams: weightGrams,
      quantityConfidence: quantityConfidence,
      nutritionConfidence: confidence,
      manualReferenceConfidence: confidence,
      referenceAccepted: true,
      suggestedProduct: product ?? suggestedProduct,
      manualReferenceNutrition: nutrition,
      manualReferenceName: displayName,
    );
  }

  MealPhotoReviewItem adjust({
    required double grams,
    required double quantityConfidence,
    required double nutritionConfidence,
    required bool reviewed,
  }) => MealPhotoReviewItem(
    proposal: proposal,
    selectionMethod: selectionMethod,
    weightGrams: grams,
    quantityConfidence: quantityConfidence,
    nutritionConfidence: nutritionConfidence,
    product: product,
    suggestedProduct: suggestedProduct,
    referenceAccepted: referenceAccepted,
    reviewed: reviewed,
    manualReferenceNutrition: manualReferenceNutrition,
    manualReferenceName: manualReferenceName,
    manualReferenceConfidence: product == null && referenceAccepted
        ? nutritionConfidence
        : manualReferenceConfidence,
  );
}

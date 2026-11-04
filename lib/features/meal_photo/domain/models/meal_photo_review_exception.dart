enum MealPhotoReviewFailure {
  energyMacrosRequired,
  actionableCarbsRequired,
  invalidMass,
  invalidCarbohydrateFacts,
  legacyReferenceUnsupported,
  futureTimeRequired,
}

/// Keeps review failures distinguishable without coupling validation to l10n.
class MealPhotoReviewException extends StateError {
  MealPhotoReviewException(this.failure) : super(failure.name);
  final MealPhotoReviewFailure failure;
}

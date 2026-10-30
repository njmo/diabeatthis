enum IngredientPhotoScanPhoto { front, nutritionLabel }

class IngredientPhotoScanInput {
  final String? frontPhotoPath;
  final String? nutritionLabelPhotoPath;

  const IngredientPhotoScanInput({
    this.frontPhotoPath,
    this.nutritionLabelPhotoPath,
  });

  bool get hasFrontPhoto => frontPhotoPath != null;

  bool get hasNutritionLabelPhoto => nutritionLabelPhotoPath != null;

  bool get hasRequiredPhotos => hasFrontPhoto && hasNutritionLabelPhoto;

  String? pathFor(IngredientPhotoScanPhoto photo) {
    return switch (photo) {
      IngredientPhotoScanPhoto.front => frontPhotoPath,
      IngredientPhotoScanPhoto.nutritionLabel => nutritionLabelPhotoPath,
    };
  }

  IngredientPhotoScanInput withPhoto(
    IngredientPhotoScanPhoto photo,
    String path,
  ) {
    return switch (photo) {
      IngredientPhotoScanPhoto.front => IngredientPhotoScanInput(
        frontPhotoPath: path,
        nutritionLabelPhotoPath: nutritionLabelPhotoPath,
      ),
      IngredientPhotoScanPhoto.nutritionLabel => IngredientPhotoScanInput(
        frontPhotoPath: frontPhotoPath,
        nutritionLabelPhotoPath: path,
      ),
    };
  }
}

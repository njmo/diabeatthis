class MealPhotoInput {
  const MealPhotoInput({
    required this.mealPhotoPath,
    this.description = '',
    this.languageCode = 'en',
    this.menuPhotoPath,
    this.residenceCountry,
  });
  final String mealPhotoPath;
  final String description;
  final String languageCode;
  final String? residenceCountry;

  MealPhotoInput withLanguageCode(String value) => MealPhotoInput(
    mealPhotoPath: mealPhotoPath,
    description: description,
    menuPhotoPath: menuPhotoPath,
    languageCode: value,
    residenceCountry: residenceCountry,
  );
  MealPhotoInput withResidenceCountry(String? value) => MealPhotoInput(
    mealPhotoPath: mealPhotoPath,
    description: description,
    menuPhotoPath: menuPhotoPath,
    languageCode: languageCode,
    residenceCountry: value?.trim().isEmpty == true ? null : value?.trim(),
  );
  final String? menuPhotoPath;
  List<String> get imagePaths => [
    mealPhotoPath,
    if (menuPhotoPath != null) menuPhotoPath!,
  ];
  bool get hasCompositionEvidence =>
      description.trim().isNotEmpty ||
      (menuPhotoPath?.trim().isNotEmpty ?? false);
  void validate() {
    if (mealPhotoPath.trim().isEmpty ||
        description.length > 4000 ||
        menuPhotoPath?.trim().isEmpty == true) {
      throw ArgumentError('Invalid meal photo input');
    }
  }
}

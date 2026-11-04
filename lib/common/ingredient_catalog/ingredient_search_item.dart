import 'ingredient_identity.dart';

class IngredientSearchItem {
  const IngredientSearchItem({
    required this.identity,
    required this.name,
    this.englishName,
    this.details = '',
    this.languageCode = 'en',
    this.iconAssetPath,
    this.localIngredientId,
    this.sourceRevision,
    this.nutritionConfidenceAssessed = true,
    this.isReference = false,
  });
  final IngredientIdentity identity;
  final String name;
  final String? englishName;
  final String details;
  final String languageCode;
  final String? iconAssetPath;
  final int? localIngredientId;
  final String? sourceRevision;
  final bool nutritionConfidenceAssessed;
  final bool isReference;
  bool get isRemote => identity.source == IngredientSource.firebase;
}

import 'ingredient_identity.dart';

class IngredientOriginSnapshot {
  const IngredientOriginSnapshot({
    required this.localIngredientId,
    required this.identity,
    required this.nutritionConfidenceAssessed,
    required this.creationMethod,
    this.sourceRevision,
    this.englishName,
    this.displayLanguageCode,
    this.sourceSnapshotJson,
    this.referenceScope,
    this.provenanceJson,
    this.copiedFromJson,
  });
  final int localIngredientId;
  final IngredientIdentity identity;
  final bool nutritionConfidenceAssessed;
  final String creationMethod;
  final String? sourceRevision;
  final String? englishName;
  final String? displayLanguageCode;
  final String? sourceSnapshotJson;
  final String? referenceScope;
  final String? provenanceJson;
  final String? copiedFromJson;
}

abstract interface class IngredientOriginRepository {
  Future<IngredientOriginSnapshot?> read(int localIngredientId);

  /// Assessment is a local user action. Source catalog facts stay immutable.
  Future<void> markConfidenceAssessed(int localIngredientId);
}

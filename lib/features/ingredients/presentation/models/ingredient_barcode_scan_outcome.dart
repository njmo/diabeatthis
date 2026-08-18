import '../../../../core/domain/model/ingredient.dart' as domain;
import '../../data/drafts/ingredient_draft.dart';

enum IngredientBarcodeScanOutcomeType {
  existingIngredient,
  newDraft,
  needsReview,
  failed,
}

class IngredientBarcodeScanOutcome {
  final IngredientBarcodeScanOutcomeType type;
  final domain.Ingredient? existingIngredient;
  final IngredientDraft? draft;
  final Object? error;

  const IngredientBarcodeScanOutcome._({
    required this.type,
    this.existingIngredient,
    this.draft,
    this.error,
  });

  const IngredientBarcodeScanOutcome.existingIngredient(
    domain.Ingredient ingredient,
  ) : this._(
        type: IngredientBarcodeScanOutcomeType.existingIngredient,
        existingIngredient: ingredient,
      );

  const IngredientBarcodeScanOutcome.newDraft(IngredientDraft draft)
    : this._(type: IngredientBarcodeScanOutcomeType.newDraft, draft: draft);

  const IngredientBarcodeScanOutcome.needsReview(IngredientDraft draft)
    : this._(type: IngredientBarcodeScanOutcomeType.needsReview, draft: draft);

  const IngredientBarcodeScanOutcome.failed(Object? error)
    : this._(type: IngredientBarcodeScanOutcomeType.failed, error: error);
}

import '../../../../core/domain/model/ingredient.dart' as domain;
import '../../data/drafts/ingredient_draft.dart';
import '../../data/models/ingredient_scan_result.dart';

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
  final List<RecognizedPortion> portions;

  const IngredientBarcodeScanOutcome._({
    required this.type,
    this.existingIngredient,
    this.draft,
    this.error,
    this.portions = const [],
  });

  const IngredientBarcodeScanOutcome.existingIngredient(
    domain.Ingredient ingredient,
  ) : this._(
        type: IngredientBarcodeScanOutcomeType.existingIngredient,
        existingIngredient: ingredient,
      );

  const IngredientBarcodeScanOutcome.newDraft(
    IngredientDraft draft, {
    List<RecognizedPortion> portions = const [],
  }) : this._(
         type: IngredientBarcodeScanOutcomeType.newDraft,
         draft: draft,
         portions: portions,
       );

  const IngredientBarcodeScanOutcome.needsReview(
    IngredientDraft draft, {
    List<RecognizedPortion> portions = const [],
  }) : this._(
         type: IngredientBarcodeScanOutcomeType.needsReview,
         draft: draft,
         portions: portions,
       );

  const IngredientBarcodeScanOutcome.failed(Object? error)
    : this._(type: IngredientBarcodeScanOutcomeType.failed, error: error);
}

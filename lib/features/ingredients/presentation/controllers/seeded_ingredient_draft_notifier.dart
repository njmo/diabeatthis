import '../../data/drafts/ingredient_draft.dart';
import '../../data/providers/ingredient_provider.dart';

class SeededIngredientDraftNotifier extends IngredientDraftNotifier {
  SeededIngredientDraftNotifier(this.initialDraft);
  final IngredientDraft initialDraft;

  @override
  IngredientDraft build() => initialDraft;
}

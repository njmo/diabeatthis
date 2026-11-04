import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/ingredient_catalog/ingredient_catalog_providers.dart';
import '../../../../common/ingredient_catalog/ingredient_search_item.dart';
import '../../data/drafts/ingredient_draft.dart';
import '../../data/mappers/ingredient_draft_mapper.dart';
import '../../data/providers/ingredient_provider.dart';

final ingredientCatalogSelectionControllerProvider =
    Provider<IngredientCatalogSelectionController>(
      (ref) => IngredientCatalogSelectionController(ref),
    );

class IngredientCatalogSelectionController {
  const IngredientCatalogSelectionController(this.ref);
  final Ref ref;
  Future<IngredientDraft> select(
    IngredientSearchItem item, {
    required String languageCode,
  }) async {
    final id = await ref.read(selectIngredientSearchItemUseCaseProvider)(
      item,
      languageCode: languageCode,
    );
    final ingredient = await ref.read(ingredientByIdProvider(id).future);
    return ingredient.toDraft();
  }
}

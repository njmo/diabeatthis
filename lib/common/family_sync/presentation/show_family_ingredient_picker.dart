import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ingredient_catalog/ingredient_catalog_providers.dart';
import '../../ingredient_catalog/ingredient_catalog_repository.dart';
import '../../ingredient_catalog/ingredient_search_item.dart';
import '../../ingredient_catalog/unified_ingredient_search_use_case.dart';
import '../../ingredient_catalog/widgets/ingredient_catalog_picker.dart';
import '../family_ingredient_search_repository.dart';

Future<IngredientSearchItem?> showFamilyIngredientPicker(
  BuildContext context, {
  required List<Map<String, dynamic>> rows,
  required IngredientCatalogRepository catalog,
}) => showModalBottomSheet<IngredientSearchItem>(
  context: context,
  isScrollControlled: true,
  builder: (_) => ProviderScope(
    overrides: [
      unifiedIngredientSearchUseCaseProvider.overrideWithValue(
        UnifiedIngredientSearchUseCase(
          local: FamilyIngredientSearchRepository(rows),
          catalog: catalog,
        ),
      ),
    ],
    child: const IngredientCatalogPicker(searchOnly: true),
  ),
);

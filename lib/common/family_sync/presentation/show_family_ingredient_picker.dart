import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../ingredient_catalog/ingredient_catalog_providers.dart';
import '../../ingredient_catalog/ingredient_catalog_repository.dart';
import '../../ingredient_catalog/ingredient_search_item.dart';
import '../../ingredient_catalog/local_ingredient_search_repository.dart';
import '../../ingredient_catalog/unified_ingredient_search_use_case.dart';
import '../../ingredient_catalog/widgets/ingredient_catalog_picker.dart';
import '../../routing/form_route_guard.dart';
import '../family_ingredient_search_repository.dart';

Future<IngredientSearchItem?> showFamilyIngredientPicker(
  BuildContext context, {
  required List<Map<String, dynamic>> rows,
  required IngredientCatalogRepository catalog,
  FormRouteGuard? routeGuard,
}) => showFamilyIngredientSearchPicker(
  context,
  local: FamilyIngredientSearchRepository(rows),
  catalog: catalog,
  routeGuard: routeGuard,
);

Future<IngredientSearchItem?> showFamilyIngredientSearchPicker(
  BuildContext context, {
  required LocalIngredientSearchRepository local,
  required IngredientCatalogRepository catalog,
  FormRouteGuard? routeGuard,
  Duration queryDebounce = Duration.zero,
}) {
  final guard = routeGuard ?? formRouteGuardOf(context);
  return showModalBottomSheet<IngredientSearchItem>(
    context: context,
    isScrollControlled: true,
    builder: (_) => guard(
      ProviderScope(
        overrides: [
          unifiedIngredientSearchUseCaseProvider.overrideWithValue(
            UnifiedIngredientSearchUseCase(local: local, catalog: catalog),
          ),
        ],
        child: IngredientCatalogPicker(
          searchOnly: true,
          queryDebounce: queryDebounce,
        ),
      ),
    ),
  );
}

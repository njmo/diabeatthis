import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../app/router/app_router.dart' as routes;
import '../../../../common/presentation/collections/controllers/ingredients_controller.dart';
import '../../../../common/presentation/collections/models/collection_state.dart';
import '../../data/providers/ingredient_provider.dart';
import 'ingredient_list/ingredient_list_content.dart';

class IngredientList extends HookConsumerWidget {
  const IngredientList({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queryController = useTextEditingController();
    final query = useState('');
    final limit = useState(ingredientListPageSize);
    final normalized = query.value.trim();
    final source = normalized.isEmpty
        ? ref.watch(ingredientListStreamProvider)
        : ref.watch(ingredientsByQueryStreamProvider(normalized));
    final all = source.value ?? const [];
    final hasMore = normalized.isEmpty && all.length > limit.value;
    return SafeArea(
      bottom: false,
      child: IngredientListContent.controlled(
        queryController: queryController,
        onQueryChanged: (value) => query.value = value,
        controller: PatientIngredientsController(
          state: CollectionState(
            items: normalized.isEmpty ? all.take(limit.value).toList() : all,
            loading: source.isLoading,
            failed: source.hasError,
            hasMore: hasMore,
          ),
          open: (item) => context.router.push(
            routes.IngredientRoute(ingredientId: item.id),
          ),
          onLoadMore: () {
            if (hasMore) limit.value += ingredientListPageSize;
          },
          onRetry: () {
            if (normalized.isEmpty) {
              ref.invalidate(ingredientListStreamProvider);
            } else {
              ref.invalidate(ingredientsByQueryStreamProvider(normalized));
            }
          },
        ),
      ),
    );
  }
}

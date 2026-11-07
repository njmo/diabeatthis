import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../features/ingredients/presentation/widgets/ingredient_details_header.dart';
import '../../../features/ingredients/presentation/widgets/ingredient_history_section.dart';
import '../../../features/ingredients/presentation/widgets/ingredient_meals_section.dart';
import '../../../features/ingredients/presentation/widgets/ingredient_nutrition_card.dart';
import '../../../features/ingredients/presentation/widgets/ingredient_portions_section.dart';
import '../../ingredient_catalog/widgets/ingredient_origin_badge.dart';
import '../../l10n/language.dart';
import '../../widgets/detail_tabs.dart';
import 'ingredient_preview_controller.dart';

/// Identical ingredient preview; editing belongs to the source's page shell.
class IngredientDetailsView extends HookWidget {
  const IngredientDetailsView({super.key, required this.controller, this.tabs});
  final IngredientPreviewController controller;
  final TabController? tabs;

  @override
  Widget build(BuildContext context) {
    final data = controller.data;
    final ownTabs = useTabController(
      initialLength:
          1 +
          (controller.showUsages ? 1 : 0) +
          (controller.showHistory ? 1 : 0),
      keys: [controller.showUsages, controller.showHistory],
    );
    final tabController = tabs ?? ownTabs;
    Widget scroll(Widget child) => SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: child,
    );
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) => [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: IngredientDetailsHeader(
              ingredient: data.ingredient,
              showConfidence: controller.showConfidence,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: DetailTabs(
              controller: tabController,
              labels: [
                context.lang.ingredientDataTab,
                if (controller.showUsages) context.lang.ingredientMealsTab,
                if (controller.showHistory) context.lang.ingredientHistoryTab,
              ],
            ),
          ),
        ),
      ],
      body: TabBarView(
        controller: tabController,
        children: [
          scroll(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (data.origin != null) ...[
                  IngredientOriginBadge(origin: data.origin!),
                  const SizedBox(height: 16),
                ],
                if (!data.confidenceIsAssessed) ...[
                  Text(context.lang.catalogUnassessedConfidence),
                  const SizedBox(height: 8),
                ],
                IngredientNutritionCard(ingredient: data.ingredient),
                const SizedBox(height: 16),
                if (controller.showPortions && !data.ingredient.isReference)
                  IngredientPortionsSection(portions: data.portions),
              ],
            ),
          ),
          if (controller.showUsages)
            scroll(
              IngredientMealsSection(
                usages: data.usages,
                onOpenMeal: controller.openMeal,
              ),
            ),
          if (controller.showHistory)
            scroll(
              IngredientHistorySection(
                history: data.history,
                ingredient: data.ingredient,
                showConfidence: controller.showConfidence,
              ),
            ),
        ],
      ),
    );
  }
}

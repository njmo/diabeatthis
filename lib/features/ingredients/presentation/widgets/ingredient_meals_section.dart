import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/app_router.dart' as routes;
import '../../../../common/l10n/language.dart';
import '../../../../common/l10n/meal_entry_label.dart';
import '../../../../common/widgets/section_surface.dart';
import '../../../meals/presentation/widgets/meal_details/meal_detail_formatters.dart';
import '../../data/models/ingredient_usage_data.dart';
import 'ingredient_section_empty.dart';

class IngredientMealsSection extends StatelessWidget {
  const IngredientMealsSection({super.key, required this.usages});

  final List<IngredientUsageData> usages;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        context.lang.ingredientUsedInMealsTitle,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 12),
      if (usages.isEmpty)
        IngredientSectionEmpty(
          icon: Icons.no_meals_outlined,
          label: context.lang.ingredientUsedInMealsEmpty,
        )
      else
        for (final meal in usages) ...[
          SectionSurface(
            padding: EdgeInsets.zero,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () =>
                  context.router.push(routes.MealRoute(mealId: meal.mealId)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.restaurant_outlined,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            mealEntryLabel(
                              purpose: meal.purpose,
                              name: meal.name,
                              lang: context.lang,
                            ),
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.open_in_new_rounded, size: 18),
                      ],
                    ),
                    if (meal.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(meal.description),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        Text(
                          DateFormat.yMMMd(
                            context.lang.localeName,
                          ).add_Hm().format(meal.plannedAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          mealStatusLabel(meal.status),
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
    ],
  );
}

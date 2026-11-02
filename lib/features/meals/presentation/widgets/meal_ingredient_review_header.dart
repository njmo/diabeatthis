import 'package:flutter/material.dart';

import '../../../../common/widgets/section_surface.dart';
import '../../../ingredients/presentation/widgets/ingredient_icon.dart';

class MealIngredientReviewHeader extends StatelessWidget {
  const MealIngredientReviewHeader({
    super.key,
    required this.name,
    required this.description,
    this.iconAssetPath,
  });
  final String name;
  final String description;
  final String? iconAssetPath;

  @override
  Widget build(BuildContext context) => SectionSurface(
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(18),
          ),
          child: IngredientIcon(assetPath: iconAssetPath, size: 44),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

import 'package:flutter/material.dart';

import '../../data/models/ingredient_details_data.dart';
import 'ingredient_confidence_banner.dart';
import 'ingredient_icon.dart';
import 'ingredient_identity_text.dart';

class IngredientDetailsHeader extends StatelessWidget {
  const IngredientDetailsHeader({
    super.key,
    required this.ingredient,
    this.showConfidence = true,
  });

  final Ingredient ingredient;
  final bool showConfidence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IngredientIcon(assetPath: ingredient.iconAssetPath, size: 72),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IngredientIdentityText(
                    name: ingredient.name,
                    brand: ingredient.brand,
                    nameStyle: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                    ),
                    brandStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    spacing: 4,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (showConfidence) ...[
          const SizedBox(height: 16),
          IngredientConfidenceBanner(value: ingredient.nutritionConfidence),
        ],
      ],
    );
  }
}

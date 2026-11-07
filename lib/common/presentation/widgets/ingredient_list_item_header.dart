import 'package:flutter/material.dart';

import '../../../core/domain/model/ingredient.dart';
import '../../../features/ingredients/presentation/widgets/ingredient_icon.dart';
import '../../../features/ingredients/presentation/widgets/ingredient_identity_text.dart';
import 'ingredient_reference_badge.dart';

class IngredientListItemHeader extends StatelessWidget {
  final Ingredient ingredient;

  const IngredientListItemHeader({super.key, required this.ingredient});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IngredientIcon(assetPath: ingredient.iconAssetPath),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IngredientIdentityText(
                name: ingredient.name,
                brand: ingredient.brand,
              ),
            ],
          ),
        ),
        if (ingredient.isReference) const IngredientReferenceBadge(),
      ],
    );
  }
}

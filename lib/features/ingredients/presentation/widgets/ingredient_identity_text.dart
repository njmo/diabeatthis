import 'package:flutter/material.dart';

class IngredientIdentityText extends StatelessWidget {
  const IngredientIdentityText({
    super.key,
    required this.name,
    this.brand,
    this.nameStyle,
    this.brandStyle,
    this.spacing = 2,
  });

  final String name;
  final String? brand;
  final TextStyle? nameStyle;
  final TextStyle? brandStyle;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(name, style: nameStyle ?? textTheme.titleMedium),
        SizedBox(height: spacing),
        Text(
          ingredientBrandLabel(brand),
          style: brandStyle ?? textTheme.bodySmall,
        ),
      ],
    );
  }
}

String ingredientBrandLabel(String? brand) {
  final value = brand?.trim();
  if (value == null || value.isEmpty) {
    return 'Bez marki';
  }
  return value;
}

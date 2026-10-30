import 'package:flutter/material.dart';

import 'ingredient_icon.dart';

class IngredientIconOption extends StatelessWidget {
  const IngredientIconOption({
    super.key,
    required this.assetPath,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String assetPath;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        selected: selected,
        button: true,
        child: Material(
          color: selected
              ? colors.primary.withValues(alpha: 0.12)
              : colors.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: selected
                  ? colors.primary
                  : colors.outlineVariant.withValues(alpha: 0.35),
              width: selected ? 2 : 1,
            ),
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                Center(child: IngredientIcon(assetPath: assetPath, size: 48)),
                if (selected)
                  Positioned(
                    right: 5,
                    top: 5,
                    child: Icon(
                      Icons.check_circle,
                      size: 15,
                      color: colors.primary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

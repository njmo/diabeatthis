import 'package:flutter/material.dart';

import '../../../../common/storage/local_image_store.dart';
import '../../../../common/widgets/local_stored_image.dart';
import '../../data/icons/food_icon_assets.dart';
import 'missing_ingredient_icon.dart';

class IngredientIcon extends StatelessWidget {
  const IngredientIcon({super.key, this.assetPath, this.size = 40});

  final String? assetPath;
  final double size;

  @override
  Widget build(BuildContext context) {
    final selected = assetPath;
    if (LocalImageStore.contains(selected)) {
      return LocalStoredImage(
        path: selected!,
        size: size,
        placeholder: MissingIngredientIcon(size: size),
      );
    }
    if (!FoodIconAssets.contains(selected) ||
        selected == FoodIconAssets.generic) {
      return MissingIngredientIcon(size: size);
    }
    return Image.asset(
      selected!,
      width: size,
      height: size,
      fit: BoxFit.contain,
      cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).ceil(),
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => MissingIngredientIcon(size: size),
    );
  }
}

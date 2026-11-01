import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/editable_thumbnail.dart';
import 'ingredient_icon.dart';
import 'ingredient_icon_picker.dart';

class IngredientIconButton extends StatelessWidget {
  const IngredientIconButton({
    super.key,
    required this.name,
    this.brand,
    this.assetPath,
    this.editablePreview = false,
    this.previewSize = 76,
    required this.onSelected,
    this.onAbandonedSelection,
  });

  final String name;
  final String? brand;
  final String? assetPath;
  final bool editablePreview;
  final double previewSize;
  final ValueChanged<String> onSelected;
  final ValueChanged<String>? onAbandonedSelection;

  @override
  Widget build(BuildContext context) {
    Future<void> choose() async {
      final path = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.7,
            child: IngredientIconPicker(
              name: name,
              brand: brand,
              selectedAssetPath: assetPath,
              onAbandonedSelection: onAbandonedSelection,
            ),
          ),
        ),
      );
      if (path == null) return;
      if (context.mounted) {
        onSelected(path);
      } else {
        onAbandonedSelection?.call(path);
      }
    }

    final icon = IngredientIcon(
      assetPath: assetPath,
      size: editablePreview ? (previewSize - 16).clamp(24, 48).toDouble() : 48,
    );
    if (editablePreview) {
      return EditableThumbnail(
        size: previewSize,
        tooltip: context.lang.ingredientChooseIcon,
        onPressed: choose,
        child: icon,
      );
    }
    return IconButton(
      tooltip: context.lang.ingredientChooseIcon,
      onPressed: choose,
      icon: icon,
    );
  }
}

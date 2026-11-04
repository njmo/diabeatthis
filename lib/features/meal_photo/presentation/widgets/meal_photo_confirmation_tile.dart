import 'package:flutter/material.dart';

import '../../domain/models/meal_photo_review_item.dart';
import 'meal_photo_selection_origin.dart';

class MealPhotoConfirmationTile extends StatelessWidget {
  const MealPhotoConfirmationTile({super.key, required this.item});
  final MealPhotoReviewItem item;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
    dense: true,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    title: Row(
      children: [
        Expanded(
          child: Text(
            item.displayName,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${item.weightGrams?.toStringAsFixed(0) ?? "—"} g',
          style: Theme.of(context).textTheme.titleSmall,
        ),
      ],
    ),
    subtitle: MealPhotoSelectionOrigin(item: item),
  );
}

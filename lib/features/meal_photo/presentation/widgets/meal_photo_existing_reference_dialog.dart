import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../domain/models/meal_photo_candidate.dart';
import 'meal_photo_nutrition_summary.dart';

/// Returns an existing product, true for an explicit new version, or null on cancel.
class MealPhotoExistingReferenceDialog extends StatelessWidget {
  const MealPhotoExistingReferenceDialog({super.key, required this.matches});
  final List<MealPhotoCandidate> matches;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(context.lang.mealPhotoReferenceAlreadyExists),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.lang.mealPhotoReuseReferenceHint),
          for (final match in matches)
            ListTile(
              title: Text(match.name),
              subtitle: MealPhotoNutritionSummary(
                nutrition: match.nutritionPer100g,
              ),
              onTap: () => Navigator.pop(context, match),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.lang.commonCancel),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context, true),
        child: Text(context.lang.mealPhotoCreateReferenceVersion),
      ),
    ],
  );
}

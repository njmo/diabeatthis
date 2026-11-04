import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../domain/models/meal_photo_nutrition.dart';
import '../../domain/models/meal_photo_proposal.dart';
import 'meal_photo_reference_preview.dart';

class MealPhotoModeSelector extends StatelessWidget {
  const MealPhotoModeSelector({
    super.key,
    required this.proposal,
    required this.onUseWholePlate,
    required this.onDivide,
    this.onEditReference,
    this.referenceNutrition,
    this.referenceConfidence,
  });
  final MealPhotoProposal proposal;
  final VoidCallback onUseWholePlate;
  final VoidCallback onDivide;
  final VoidCallback? onEditReference;
  final MealPhotoNutrition? referenceNutrition;
  final double? referenceConfidence;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      MealPhotoReferencePreview(
        proposal: proposal,
        referenceNutrition: referenceNutrition,
        referenceConfidence: referenceConfidence,
      ),
      if (onEditReference != null)
        TextButton.icon(
          onPressed: onEditReference,
          icon: const Icon(Icons.edit_outlined),
          label: Text(context.lang.ingredientEditReferenceData),
        ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: onUseWholePlate,
        child: Text(context.lang.mealPhotoUseWholePlate),
      ),
      const SizedBox(height: 8),
      TextButton.icon(
        onPressed: onDivide,
        icon: const Icon(Icons.call_split),
        label: Text(context.lang.mealPhotoDivideIngredients),
      ),
    ],
  );
}

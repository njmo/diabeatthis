import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../domain/models/meal_photo_proposal_stage.dart';

class MealPhotoGenerationProgress extends StatelessWidget {
  const MealPhotoGenerationProgress({super.key, this.stage});
  final MealPhotoProposalStage? stage;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const CircularProgressIndicator(),
      const SizedBox(height: 12),
      Text(switch (stage) {
        MealPhotoProposalStage.findingProducts =>
          context.lang.mealPhotoProgressProducts,
        MealPhotoProposalStage.resolving =>
          context.lang.mealPhotoProgressResolving,
        MealPhotoProposalStage.validating =>
          context.lang.mealPhotoProgressValidating,
        _ => context.lang.mealPhotoProgressRecognizing,
      }),
    ],
  );
}

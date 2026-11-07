import 'package:flutter/material.dart';

import '../../features/meals/data/drafts/meal_draft.dart';
import '../nutrition/confidence_level.dart';

class MealAmountBindings {
  const MealAmountBindings({
    required this.draft,
    required this.amount,
    required this.confidence,
    required this.formKey,
    required this.onAmount,
    required this.onConfidence,
  });
  final MealIngredientsDraft draft;
  final double amount;
  final ConfidenceLevel confidence;
  final GlobalKey<FormState> formKey;
  final ValueChanged<double> onAmount;
  final ValueChanged<ConfidenceLevel> onConfidence;
}

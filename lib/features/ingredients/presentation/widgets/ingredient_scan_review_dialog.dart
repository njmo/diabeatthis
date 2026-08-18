import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import '../../data/models/ingredient_scan_result.dart';

Future<bool?> showIngredientScanReviewDialog({
  required BuildContext context,
  required IngredientScanResult result,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => IngredientScanReviewDialog(result: result),
  );
}

class IngredientScanReviewDialog extends StatelessWidget {
  final IngredientScanResult result;

  const IngredientScanReviewDialog({required this.result, super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final nutrition = result.nutritionPer100g;

    return AlertDialog(
      title: Text(lang.ingredientScanIncompleteTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IngredientScanReviewRow(
            label: lang.ingredientNameLabel,
            value: result.name,
          ),
          IngredientScanReviewRow(
            label: lang.ingredientBrandLabel,
            value: result.brand,
          ),
          IngredientScanReviewRow(
            label: lang.mealCarbsLabel,
            value: _formatGrams(nutrition?.carbs),
          ),
          IngredientScanReviewRow(
            label: lang.mealFatLabel,
            value: _formatGrams(nutrition?.fat),
          ),
          IngredientScanReviewRow(
            label: lang.mealProteinLabel,
            value: _formatGrams(nutrition?.protein),
          ),
          IngredientScanReviewRow(
            label: lang.mealFiberLabel,
            value: _formatGrams(nutrition?.fiber),
          ),
          const SizedBox(height: 12),
          Text(
            lang.ingredientScanIncompleteMessage,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(lang.commonRetry),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(lang.ingredientContinueWithDraft),
        ),
      ],
    );
  }
}

class IngredientScanReviewRow extends StatelessWidget {
  final String label;
  final String? value;

  const IngredientScanReviewRow({
    required this.label,
    required this.value,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasValue = value != null && value!.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            hasValue ? value! : context.lang.commonMissingLowercase,
            style: TextStyle(
              color: hasValue ? colors.onSurface : colors.error,
              fontWeight: hasValue ? FontWeight.w500 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

String? _formatGrams(double? value) {
  if (value == null) {
    return null;
  }
  if (value == value.roundToDouble()) {
    return '${value.toStringAsFixed(0)} g';
  }
  return '${value.toStringAsFixed(1)} g';
}

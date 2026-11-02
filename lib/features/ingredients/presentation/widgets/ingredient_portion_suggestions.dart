import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/portions/standard_portion_names.dart';
import '../../data/models/ingredient_scan_result.dart';

class IngredientPortionSuggestions extends StatelessWidget {
  final List<RecognizedPortion> suggestions;
  final ValueChanged<RecognizedPortion> onSelected;

  const IngredientPortionSuggestions({
    required this.suggestions,
    required this.onSelected,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();
    final lang = context.lang;
    final theme = Theme.of(context);
    final number = NumberFormat.decimalPattern(lang.localeName);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              lang.ingredientRecognizedPortions,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              lang.ingredientRecognizedPortionsHint,
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final suggestion in suggestions)
                  ActionChip(
                    avatar: const Icon(Icons.add_circle_outline, size: 18),
                    label: Text(
                      '${localizedPortionName(suggestion.name ?? '', lang)} · ${number.format(suggestion.grams)} g',
                    ),
                    onPressed: () => onSelected(suggestion),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';
import 'ingredient_form.dart';

class IngredientEditMode extends StatelessWidget {
  const IngredientEditMode({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.edit,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  context.lang.ingredientEditTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const IngredientForm(showReferenceToggle: false),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../meals/data/providers/add_ingredients_provider.dart';
import 'ingredient_form.dart';

class IngredientEditMode extends ConsumerWidget {
  final bool isSaving;
  final VoidCallback onCancel;
  final Future<void> Function() onSave;

  const IngredientEditMode({
    super.key,
    required this.isSaving,
    required this.onCancel,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  'Edycja składnika',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const IngredientForm(showReferenceToggle: false),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: isSaving ? null : onCancel,
                  icon: const Icon(Icons.close),
                  label: const Text('Anuluj'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: isSaving ? null : () => _save(ref),
                  icon: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: const Text('Zapisz'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(WidgetRef ref) async {
    final formKey = ref.read(mealIngredientFormKeyProvider);
    if (!(formKey.currentState?.validate() ?? false)) {
      return;
    }

    await onSave();
  }
}

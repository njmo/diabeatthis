import 'package:flutter/material.dart';

class IngredientMultiPickerFooter extends StatelessWidget {
  final VoidCallback onConfirm;

  const IngredientMultiPickerFooter({super.key, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: FilledButton.icon(
        onPressed: onConfirm,
        icon: const Icon(Icons.check),
        label: const Text('Zatwierdź'),
      ),
    );
  }
}

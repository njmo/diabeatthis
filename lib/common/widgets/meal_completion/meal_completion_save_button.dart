import 'package:flutter/material.dart';

class MealCompletionSaveButton extends StatelessWidget {
  const MealCompletionSaveButton({
    super.key,
    required this.label,
    required this.saving,
    required this.onPressed,
    this.error,
    this.icon = Icons.check,
  });

  final String label;
  final bool saving;
  final VoidCallback? onPressed;
  final String? error;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null) ...[
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 8),
        ],
        FilledButton.icon(
          onPressed: onPressed,
          icon: saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(icon),
          label: Text(label),
        ),
      ],
    ),
  );
}

import 'package:flutter/material.dart';

import '../l10n/language.dart';

class AapsSuggestionFallbackDialog extends StatelessWidget {
  const AapsSuggestionFallbackDialog({super.key, required this.instruction});

  final String instruction;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    return AlertDialog(
      scrollable: true,
      title: Text(lang.aapsSuggestionUnavailableTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(lang.aapsSuggestionUnavailableMessage),
          const SizedBox(height: 16),
          SelectableText(
            instruction,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(lang.settingsCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(lang.mealProgressOpenCalculator),
        ),
      ],
    );
  }
}

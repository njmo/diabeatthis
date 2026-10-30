import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';

class IngredientEditActions extends StatelessWidget {
  const IngredientEditActions({
    super.key,
    required this.isSaving,
    required this.onSave,
    required this.onCancel,
  });

  final bool isSaving;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: isSaving ? null : onCancel,
              child: Text(context.lang.commonCancel),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: isSaving ? null : onSave,
              icon: isSaving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(context.lang.commonSave),
            ),
          ),
        ],
      ),
    ),
  );
}

import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';

class IngredientMultiPickerSearchField extends StatelessWidget {
  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const IngredientMultiPickerSearchField({
    super.key,
    required this.controller,
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final scheme = Theme.of(context).colorScheme;
    const topRadius = BorderRadius.vertical(top: Radius.circular(24));

    return ClipRRect(
      borderRadius: topRadius,
      child: ColoredBox(
        color: scheme.surface,
        child: SizedBox(
          height: 58,
          child: Center(
            child: TextField(
              controller: controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: lang.ingredientSearchLabel,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: lang.commonClearTooltip,
                        icon: const Icon(Icons.close),
                        onPressed: onClear,
                      ),
                filled: true,
                fillColor: scheme.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                border: UnderlineInputBorder(
                  borderSide: BorderSide(color: scheme.outlineVariant),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: scheme.outlineVariant),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: scheme.primary, width: 1.5),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'ingredient_form.dart';

class IngredientEditMode extends StatelessWidget {
  const IngredientEditMode({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    );
    return Theme(
      data: theme.copyWith(
        inputDecorationTheme: theme.inputDecorationTheme.copyWith(
          filled: true,
          fillColor: colors.surfaceContainer,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          enabledBorder: border,
          disabledBorder: border,
          focusedBorder: border.copyWith(
            borderSide: BorderSide(color: colors.primary, width: 1.5),
          ),
          errorBorder: border.copyWith(
            borderSide: BorderSide(color: colors.error),
          ),
          focusedErrorBorder: border.copyWith(
            borderSide: BorderSide(color: colors.error, width: 1.5),
          ),
        ),
      ),
      child: const IngredientForm(showReferenceToggle: false, sectioned: true),
    );
  }
}

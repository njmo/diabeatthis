import 'package:flutter/material.dart';

import '../l10n/language.dart';
import '../meal/meal_category.dart';

class MealCategoryField extends StatelessWidget {
  const MealCategoryField({
    super.key,
    required this.value,
    required this.onChanged,
    this.filter = false,
    this.requiredSelection = false,
    this.compact = false,
  });
  final MealCategory? value;
  final ValueChanged<MealCategory?> onChanged;
  final bool filter;
  final bool requiredSelection;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return FormField<MealCategory>(
        key: ValueKey(value),
        initialValue: value,
        validator: (selected) => requiredSelection && selected == null
            ? context.lang.mealCategoryRequired
            : null,
        builder: (field) => InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () async {
            final target = field.context.findRenderObject() as RenderBox;
            final overlay =
                Navigator.of(context).overlay!.context.findRenderObject()
                    as RenderBox;
            final bounds = Rect.fromPoints(
              target.localToGlobal(Offset.zero, ancestor: overlay),
              target.localToGlobal(
                target.size.bottomRight(Offset.zero),
                ancestor: overlay,
              ),
            );
            final selected = await showMenu<MealCategory>(
              context: context,
              initialValue: value,
              position: RelativeRect.fromRect(
                bounds,
                Offset.zero & overlay.size,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              constraints: const BoxConstraints(minWidth: 200, maxWidth: 300),
              items: [
                for (final category in MealCategory.values)
                  PopupMenuItem(
                    value: category,
                    child: Row(
                      children: [
                        Expanded(child: Text(category.label(context.lang))),
                        if (value == category) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.check,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            );
            if (selected != null && field.mounted) {
              field.didChange(selected);
              onChanged(selected);
            }
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: requiredSelection
                  ? '${context.lang.mealCategoryLabel} *'
                  : context.lang.mealCategoryLabel,
              errorText: field.errorText,
              border: const OutlineInputBorder(),
              suffixIcon: const Icon(Icons.edit_outlined),
              isDense: true,
            ),
            child: Text(
              value?.label(context.lang) ?? context.lang.mealCategoryChoose,
            ),
          ),
        ),
      );
    }
    if (!filter) {
      return FormField<MealCategory>(
        key: ValueKey(value),
        initialValue: value,
        validator: (selected) => requiredSelection && selected == null
            ? context.lang.mealCategoryRequired
            : null,
        builder: (field) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              requiredSelection
                  ? '${context.lang.mealCategoryLabel} *'
                  : context.lang.mealCategoryLabel,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final category in MealCategory.values)
                  ChoiceChip(
                    label: Text(category.label(context.lang)),
                    selected: value == category,
                    onSelected: (selected) {
                      if (selected) {
                        field.didChange(category);
                        onChanged(category);
                      }
                    },
                  ),
              ],
            ),
            if (field.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  field.errorText!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      );
    }
    return DropdownButtonFormField<MealCategory>(
      key: ValueKey(value),
      initialValue: value,
      isExpanded: true,
      hint: Text(
        filter ? context.lang.mealCategoryAll : context.lang.mealCategoryNone,
      ),
      validator: (value) => requiredSelection && value == null
          ? context.lang.mealCategoryRequired
          : null,
      decoration: InputDecoration(
        labelText: requiredSelection
            ? '${context.lang.mealCategoryLabel} *'
            : context.lang.mealCategoryLabel,
        border: const OutlineInputBorder(),
      ),
      items: [
        DropdownMenuItem(
          value: null,
          child: Text(
            filter
                ? context.lang.mealCategoryAll
                : context.lang.mealCategoryNone,
          ),
        ),
        for (final category in MealCategory.values)
          DropdownMenuItem(
            value: category,
            child: Text(category.label(context.lang)),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

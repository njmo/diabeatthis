import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/controlled_text_form_field.dart';
import '../../../data/providers/meal_draft_provider.dart';

class MealNameField extends ConsumerWidget {
  const MealNameField({super.key, required this.onSaved});
  final ValueChanged<String> onSaved;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ControlledTextFormField(
    value: ref.watch(mealDraftProvider.select((draft) => draft.name)),
    onChanged: ref.read(mealDraftProvider.notifier).setName,
    maxLength: 120,
    textInputAction: TextInputAction.done,
    validator: (value) => (value?.trim().length ?? 0) < 5
        ? context.lang.addMealNameRequired
        : null,
    onSaved: (value) => onSaved(value!.trim()),
    decoration: InputDecoration(
      labelText: context.lang.addMealNameLabel,
      border: const OutlineInputBorder(),
    ),
  );
}

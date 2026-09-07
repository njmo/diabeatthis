import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/controlled_text_form_field.dart';
import '../../../../../common/widgets/form_section.dart';
import '../../../data/providers/meal_draft_provider.dart';
import 'meal_planned_time_field.dart';

class AddMealBasicInfoSection extends ConsumerWidget {
  const AddMealBasicInfoSection({
    super.key,
    required this.onNameSaved,
    required this.onPlannedAtChanged,
  });

  final ValueChanged<String> onNameSaved;
  final ValueChanged<DateTime> onPlannedAtChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealName = ref.watch(mealDraftProvider.select((draft) => draft.name));

    return FormSection(
      icon: Icons.restaurant_menu,
      title: context.lang.addMealBasicInfoTitle,
      subtitle: context.lang.addMealBasicInfoSubtitle,
      children: [
        ControlledTextFormField(
          value: mealName,
          onChanged: ref.read(mealDraftProvider.notifier).setName,
          maxLength: 120,
          textInputAction: TextInputAction.next,
          validator: (value) {
            final name = value?.trim() ?? '';
            if (name.length < 5) {
              return context.lang.addMealNameRequired;
            }
            return null;
          },
          onSaved: (value) => onNameSaved(value!.trim()),
          decoration: InputDecoration(
            labelText: context.lang.addMealNameLabel,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        MealPlannedTimeField(onChanged: onPlannedAtChanged),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../common/l10n/language.dart';
import '../../../../../common/widgets/form_section.dart';
import 'meal_name_field.dart';
import 'meal_planned_time_field.dart';

class AddMealBasicInfoSection extends ConsumerWidget {
  const AddMealBasicInfoSection({
    super.key,
    this.retrospective = false,
    this.initialEatenAt,
    required this.onNameSaved,
    required this.onPlannedAtChanged,
  });

  final bool retrospective;
  final DateTime? initialEatenAt;
  final ValueChanged<String> onNameSaved;
  final ValueChanged<DateTime> onPlannedAtChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FormSection(
      icon: Icons.restaurant_menu,
      title: context.lang.addMealBasicInfoTitle,
      subtitle: context.lang.addMealBasicInfoSubtitle,
      children: [
        MealNameField(onSaved: onNameSaved),
        const SizedBox(height: 12),
        MealPlannedTimeField(
          onChanged: onPlannedAtChanged,
          retrospective: retrospective,
          initialDate: initialEatenAt,
        ),
      ],
    );
  }
}

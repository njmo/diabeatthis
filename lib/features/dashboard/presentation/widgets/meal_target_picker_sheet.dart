import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/keyboard_aware_bottom_sheet.dart';
import '../../../../core/domain/model/temporary_target.dart';
import '../controllers/dashboard_status_controller.dart';

Future<int?> showMealTargetPickerSheet(
  BuildContext context,
  TemporaryTarget target, {
  int? selectedMealId,
}) => showModalBottomSheet<int>(
  context: context,
  isScrollControlled: true,
  builder: (_) =>
      MealTargetPickerSheet(target: target, selectedMealId: selectedMealId),
);

class MealTargetPickerSheet extends ConsumerWidget {
  const MealTargetPickerSheet({
    super.key,
    required this.target,
    this.selectedMealId,
  });
  final TemporaryTarget target;
  final int? selectedMealId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => KeyboardAwareBottomSheet(
    header: Text(
      context.lang.dashboardAttachMeal,
      style: Theme.of(context).textTheme.titleLarge,
    ),
    body: ref
        .watch(mealTargetCandidatesProvider(target))
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => TextButton(
            onPressed: () =>
                ref.invalidate(mealTargetCandidatesProvider(target)),
            child: Text(context.lang.commonRetry),
          ),
          data: (meals) => Column(
            children: [
              if (meals.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(context.lang.dashboardNoMealsToAttach),
                ),
              for (final meal in meals)
                ListTile(
                  selected: meal.id == selectedMealId,
                  trailing: meal.id == selectedMealId
                      ? const Icon(Icons.check_circle_outline)
                      : null,
                  leading: const Icon(Icons.restaurant_rounded),
                  title: Text(meal.name),
                  subtitle: Text(
                    '${MaterialLocalizations.of(context).formatShortDate(meal.plannedAt!.toLocal())} · '
                    '${TimeOfDay.fromDateTime(meal.plannedAt!.toLocal()).format(context)}',
                  ),
                  onTap: () => Navigator.pop(context, meal.id),
                ),
            ],
          ),
        ),
    actions: OutlinedButton(
      onPressed: () => Navigator.pop(context),
      child: Text(context.lang.settingsCancel),
    ),
  );
}

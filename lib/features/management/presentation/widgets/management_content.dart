import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../core/data_sources/config/data_source_config_provider.dart';
import '../../../activity/presentation/widgets/activity_management_panel.dart';
import '../../../ingredients/presentation/widgets/ingredient_list.dart';
import '../../../meals/presentation/widgets/meal_list.dart';

class ManagementContent extends HookConsumerWidget {
  const ManagementContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destination = useState(0);
    return ref
        .watch(dataSourceConfigProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text(context.lang.managementSettingsError(error))),
          data: (_) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(
                        value: 0,
                        label: Text(context.lang.managementMealsTab),
                      ),
                      ButtonSegment(
                        value: 1,
                        label: Text(context.lang.managementIngredientsTab),
                      ),
                      ButtonSegment(
                        value: 2,
                        label: Text(context.lang.managementActivitiesTab),
                      ),
                    ],
                    selected: {destination.value},
                    onSelectionChanged: (selection) =>
                        destination.value = selection.single,
                  ),
                ),
              ),
              Expanded(
                child: [
                  MealList(),
                  IngredientList(),
                  ActivityManagementPanel(),
                ][destination.value],
              ),
            ],
          ),
        );
  }
}

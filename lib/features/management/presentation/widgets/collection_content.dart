import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../core/data_sources/config/data_source_config_provider.dart';
import '../../../activity/presentation/widgets/activity_definition_sheet.dart';
import '../../../activity/presentation/widgets/activity_list.dart';
import '../../../activity/presentation/widgets/activity_log_list.dart';
import '../../../activity/presentation/widgets/activity_upcoming_button.dart';
import '../../../ingredients/presentation/widgets/create_ingredient_sheet.dart';
import '../../../ingredients/presentation/widgets/ingredient_list.dart';
import '../../../meals/presentation/widgets/meal_list.dart';

class CollectionContent extends ConsumerWidget {
  const CollectionContent({
    super.key,
    required this.history,
    required this.selectedIndex,
  });

  final bool history;
  final int selectedIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(dataSourceConfigProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text(context.lang.managementSettingsError(error))),
        data: (_) {
          if (history && selectedIndex == 0) return const MealList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: history
                    ? const ActivityUpcomingButton()
                    : OutlinedButton.icon(
                        icon: const Icon(Icons.add),
                        label: Text(
                          selectedIndex == 0
                              ? context.lang.addIngredientTitle
                              : context.lang.activityCreateTitle,
                        ),
                        onPressed: () {
                          if (selectedIndex == 0) {
                            showCreateIngredientSheet(context, ref);
                          } else {
                            showActivityDefinitionSheet(context);
                          }
                        },
                      ),
              ),
              Expanded(
                child: history
                    ? const ActivityLogList()
                    : selectedIndex == 0
                    ? const IngredientList()
                    : const ActivityList(),
              ),
            ],
          );
        },
      );
}

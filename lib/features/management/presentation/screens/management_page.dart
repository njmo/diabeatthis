import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../core/data_sources/config/data_source_config_provider.dart';
import '../../../activity/presentation/widgets/activity_list.dart';
import '../../../ingredients/presentation/widgets/ingredient_list.dart';
import '../../../meals/presentation/widgets/meal_list.dart';

@RoutePage()
class ManagementPage extends HookConsumerWidget {
  const ManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destination = useState(0);
    final dataSourceConfigAsync = ref.watch(dataSourceConfigProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.lang.managementTitle)),
      body: dataSourceConfigAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text(context.lang.managementSettingsError(error))),
        data: (config) {
          return <Widget>[
            MealList(),
            IngredientList(),
            ActivityList(),
          ][destination.value];
        },
      ),
      bottomNavigationBar: dataSourceConfigAsync.maybeWhen(
        data: (config) {
          return NavigationBar(
            selectedIndex: destination.value,
            destinations: <Widget>[
              NavigationDestination(
                icon: const Icon(Icons.restaurant_sharp),
                label: context.lang.managementMealsTab,
              ),
              NavigationDestination(
                icon: const Icon(Icons.bakery_dining),
                label: context.lang.managementIngredientsTab,
              ),
              NavigationDestination(
                icon: const Icon(Icons.sports_handball_outlined),
                label: context.lang.managementActivitiesTab,
              ),
            ],
            onDestinationSelected: (int index) {
              destination.value = index;
            },
          );
        },
        orElse: () => null,
      ),
    );
  }
}

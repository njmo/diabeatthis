import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../core/data_sources/config/data_source_config.dart';
import '../../../../core/data_sources/config/data_source_config_provider.dart';
import '../../../activity/presentation/widgets/activity_list.dart';
import '../../../ingredients/presentation/widgets/ingredient_list.dart';
import '../../../meals/presentation/widgets/meal_list.dart';
import '../widgets/local_history_blocked_view.dart';

@RoutePage()
class ManagementPage extends HookConsumerWidget {
  const ManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destination = useState(0);
    final dataSourceConfigAsync = ref.watch(dataSourceConfigProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Zarządzanie')),
      body: dataSourceConfigAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Błąd ustawień: $error')),
        data: (config) {
          if (config.historySource == HistorySource.local) {
            return const LocalHistoryBlockedView();
          }

          return <Widget>[
            MealList(),
            IngredientList(),
            ActivityList(),
          ][destination.value];
        },
      ),
      bottomNavigationBar: dataSourceConfigAsync.maybeWhen(
        data: (config) {
          if (config.historySource == HistorySource.local) {
            return null;
          }

          return NavigationBar(
            selectedIndex: destination.value,
            destinations: const <Widget>[
              NavigationDestination(
                icon: Icon(Icons.restaurant_sharp),
                label: 'Posiłki',
              ),
              NavigationDestination(
                icon: Icon(Icons.bakery_dining),
                label: 'Składniki',
              ),
              NavigationDestination(
                icon: Icon(Icons.sports_handball_outlined),
                label: 'Aktywności',
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

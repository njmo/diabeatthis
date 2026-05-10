import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../activity/presentation/widgets/activity_list.dart';
import '../../../ingredients/presentation/widgets/ingredient_list.dart';
import '../../../meals/presentation/widgets/meal_list.dart';
import '../../../meals/presentation/widgets/meal_list_today.dart';

@RoutePage()
class ManagementPage extends HookConsumerWidget {
  const ManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destination = useState(0);
    return Scaffold(
      appBar: AppBar(title: const Text('Zarządzanie')),
      body: <Widget>[
        MealListToday(),
        MealList(),
        IngredientList(),
        ActivityList(),
      ][destination.value],
      bottomNavigationBar: NavigationBar(
        selectedIndex: destination.value,
        destinations: const <Widget>[
          NavigationDestination(icon: Icon(Icons.today), label: 'Dziś'),
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
      ),
    );
  }
}

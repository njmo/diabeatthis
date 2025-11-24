import 'dart:math';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';


import '../../../../common/notifier_provider/simple_provider.dart';
import '../../../meals/presentation/widgets/meal_list_today.dart';
import '../widgets/dashboard_fab.dart';
import '../widgets/nightscout_dashboard.dart';

@RoutePage()
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(nameProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard'), ),
      floatingActionButton: const DashboardFAB(),
      body: Column(
        children: [
          Text('Welcome $name!'),
          NightscoutPanel(),
          const SizedBox(height: 8),
          Text('Planned meals',textAlign: TextAlign.left, style: TextStyle(fontSize: 20,),),
          MealListToday(),
        ],
      ),
    );
  }
}

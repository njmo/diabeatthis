import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/notifier_provider/simple_provider.dart';
import '../../../../core/data/provider/parent_controller_provider.dart';
import '../../../meals/presentation/widgets/meal_list_today.dart';
import '../widgets/dashboard_fab.dart';
import '../widgets/nightscout_dashboard.dart';

@RoutePage()
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(nameProvider);
    final parentModeController = ref.watch(parentModeProvider.notifier);
    final parentModeEnabled = ref.watch(parentModeProvider);

    return Scaffold(
      appBar: AppBar(
        actions: <Widget>[
          IconButton(
            icon: Icon(
              Icons.person_pin,
              color: parentModeEnabled ? Colors.green : Colors.amber,
            ),
            onPressed: () {
              parentModeController.toggleParentMode();
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              context.router.pushPath('/settings');
            },
          ),
        ],
      ),
      floatingActionButton: const DashboardFAB(),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Text('Witaj ${name.asData?.value ?? 'Name' }!'),
              NightscoutPanel(),
              const SizedBox(height: 8),
              Text(
                'Zaplanowane posiłki',
                textAlign: TextAlign.left,
                style: TextStyle(fontSize: 20),
              ),
              MealListToday(),
            ],
          ),
        ),
      ),
    );
  }
}

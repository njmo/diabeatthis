import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/notifier_provider/simple_provider.dart';
import '../../../../core/data/provider/parent_controller_provider.dart';
import '../../../day_analysis/presentation/widgets/today_page.dart';
import '../../../meals/presentation/widgets/meal_list_today.dart';
import '../widgets/dashboard_bottom_bar.dart';
import '../widgets/dashboard_fab.dart';
import '../widgets/dashboard_status_card.dart';
import '../widgets/nightscout_dashboard.dart';
import '../widgets/parent_dashboard_fab.dart';

@RoutePage()
class DashboardPage extends HookConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destination = useState(0);
    final name = ref.watch(nameProvider);
    final parentModeEnabled = ref.watch(parentModeProvider);

    return Scaffold(
      appBar: AppBar(
        actions: <Widget>[
          IconButton(
            tooltip: context.lang.dashboardManagementTooltip,
            icon: const Icon(Icons.admin_panel_settings_outlined),
            onPressed: () {
              context.router.pushPath('/management');
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: DashboardBottomBar(
        selectedIndex: destination.value,
        onSelected: (index) => destination.value = index,
      ),
      floatingActionButton: parentModeEnabled
          ? const ParentDashboardFAB()
          : const DashboardFAB(),
      body: SafeArea(
        child: destination.value == 1
            ? const TodayPage()
            : SingleChildScrollView(
                child: Column(
                  children: [
                    Text(
                      context.lang.dashboardGreeting(
                        name.asData?.value ??
                            context.lang.dashboardFallbackName,
                      ),
                    ),
                    NightscoutPanel(),
                    const DashboardStatusCard(),
                    const SizedBox(height: 8),
                    Text(
                      context.lang.dashboardPlannedMealsTitle,
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

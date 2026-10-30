import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../core/data/provider/parent_controller_provider.dart';
import '../../../day_analysis/presentation/widgets/today_page.dart';
import '../../../management/presentation/widgets/management_content.dart';
import '../../../meals/presentation/widgets/meal_list_today.dart';
import '../widgets/dashboard_bottom_bar.dart';
import '../widgets/dashboard_fab.dart';
import '../widgets/dashboard_status_card.dart';
import '../widgets/dashboard_user_menu.dart';
import '../widgets/nightscout_dashboard.dart';
import '../widgets/parent_dashboard_fab.dart';

@RoutePage()
class DashboardPage extends HookConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destination = useState(0);
    final parentModeEnabled = ref.watch(parentModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: destination.value == 2
            ? Text(context.lang.dashboardLibraryTab)
            : null,
        actions: const [DashboardUserMenu(), SizedBox(width: 8)],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endDocked,
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
            : destination.value == 2
            ? const ManagementContent()
            : SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 32),
                child: Column(
                  children: [
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

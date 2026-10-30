import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/compact_category_selector.dart';
import '../../../../core/data/provider/parent_controller_provider.dart';
import '../../../day_analysis/presentation/widgets/today_page.dart';
import '../../../management/presentation/widgets/collection_content.dart';
import '../../../meals/presentation/widgets/meal_list_today.dart';
import '../widgets/dashboard_bottom_bar.dart';
import '../widgets/dashboard_fab.dart';
import '../widgets/dashboard_greeting.dart';
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
    final historyCategory = useState(0);
    final catalogCategory = useState(0);
    final isCollection = destination.value >= 2;
    final category = destination.value == 2 ? historyCategory : catalogCategory;
    final parentModeEnabled = ref.watch(parentModeProvider);

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: destination.value == 0
            ? const DashboardGreeting()
            : isCollection
            ? Text(
                destination.value == 2
                    ? context.lang.dashboardHistoryTab
                    : context.lang.dashboardCatalogTab,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            : null,
        actions: [
          if (isCollection)
            CompactCategorySelector(
              labels: [
                destination.value == 2
                    ? context.lang.managementMealsTab
                    : context.lang.managementIngredientsTab,
                context.lang.managementActivitiesTab,
              ],
              icons: [
                destination.value == 2
                    ? Icons.restaurant_outlined
                    : Icons.egg_alt_outlined,
                Icons.directions_run,
              ],
              selectedIndex: category.value,
              onSelected: (index) => category.value = index,
            )
          else
            const DashboardUserMenu(),
          const SizedBox(width: 8),
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
        bottom: false,
        child: destination.value == 1
            ? const TodayPage()
            : isCollection
            ? CollectionContent(
                history: destination.value == 2,
                selectedIndex: category.value,
              )
            : Builder(
                builder: (context) => SingleChildScrollView(
                  padding: EdgeInsets.only(
                    bottom: 32 + MediaQuery.paddingOf(context).bottom,
                  ),
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
      ),
    );
  }
}

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/app_mode/application_device_mode.dart';
import '../../../../common/app_mode/application_device_mode_loading.dart';
import '../../../../common/presentation/dashboard/dashboard_shell.dart';
import '../../../../common/presentation/dashboard/dashboard_spacing.dart';
import '../../../../core/data/provider/parent_controller_provider.dart';
import '../../../caregiver/presentation/widgets/caregiver_dashboard.dart';
import '../../../day_analysis/presentation/widgets/today_page.dart';
import '../../../management/presentation/widgets/collection_content.dart';
import '../../../meals/presentation/widgets/meal_list_today.dart';
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
    final historyCategory = useState(0);
    final catalogCategory = useState(0);
    final isCollection = destination.value >= 2;
    final category = destination.value == 2 ? historyCategory : catalogCategory;
    final parentModeEnabled = ref.watch(parentModeProvider);

    final mode = ref.watch(applicationDeviceModeProvider);
    if (mode.isLoading || mode.hasError || mode.asData == null) {
      return const ApplicationDeviceModeLoading();
    }
    if (mode.asData?.value == ApplicationDeviceMode.caregiver) {
      return const CaregiverDashboard();
    }

    return DashboardShell(
      destination: destination.value,
      category: category.value,
      onDestination: (value) => destination.value = value,
      onCategory: (value) => category.value = value,
      actions: parentModeEnabled
          ? const ParentDashboardFAB()
          : const DashboardFAB(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: destination.value == 1
                  ? const TodayPage()
                  : isCollection
                  ? CollectionContent(
                      history: destination.value == 2,
                      selectedIndex: category.value,
                    )
                  : Builder(
                      builder: (context) => SingleChildScrollView(
                        padding: DashboardSpacing.homeScroll(context),
                        child: Column(
                          children: [
                            NightscoutPanel(),
                            const DashboardStatusCard(),
                            const SizedBox(height: 8),
                            MealListToday(),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

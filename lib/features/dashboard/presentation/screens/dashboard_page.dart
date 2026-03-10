import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../app/providers/app_lifecycle_state_provider.dart';
import '../../../../common/notifier_provider/simple_provider.dart';
import '../../../../core/data/provider/parent_controller_provider.dart';
import '../../../../core/domain/model/activity_log.dart';
import '../../../activity/data/providers/activity_provider.dart';
import '../../../meals/presentation/widgets/meal_list_today.dart';
import '../../data/providers/time_now_provider.dart';
import '../widgets/dashboard_fab.dart';
import '../widgets/kid_fab.dart';
import '../widgets/nightscout_dashboard.dart';
import '../widgets/temporary_target_icon.dart';

@RoutePage()
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(nameProvider);
    final parentModeController = ref.watch(parentModeProvider.notifier);
    final parentModeEnabled = ref.watch(parentModeProvider);
    final pendingActivity = ref.watch(getPendingActivityProvider);
    final timeNowStream = ref.watch(timeNowProvider);

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
      floatingActionButton: parentModeEnabled
          ? const DashboardFAB()
          : const KidFAB(),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Text('Witaj ${name.asData?.value ?? 'Name'}!'),
              NightscoutPanel(),
              const SizedBox(height: 8),
              pendingActivity.whenOrNull(
                    data: (d) {
                      if (d == null) return SizedBox.shrink();
                      final runningFor = timeNowStream
                          .whenData((data) => data.difference(d.startedAt))
                          .value;
                      final minutes = runningFor?.inMinutes;

                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            'Aktywność: ${d.whenOrNull(view: (_, name, _, _, _) => name)} od ${minutes.toString()} min',
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.stop_circle_outlined),
                            onPressed: () async {
                              await ref.read(stopActivityProvider(d).future);
                              ref.invalidate(getPendingActivityProvider);
                            },
                          ),
                        ],
                      );
                    },
                  ) ??
                  const SizedBox.shrink(),
              TemporaryTargetIcon(),
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

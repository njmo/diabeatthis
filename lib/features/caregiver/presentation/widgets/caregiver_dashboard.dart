import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../dashboard/presentation/widgets/dashboard_greeting.dart';
import '../../../dashboard/presentation/widgets/dashboard_user_menu.dart';
import '../../application/caregiver_ui_refresh_provider.dart';
import 'caregiver_nightscout_panel.dart';
import 'caregiver_refresh_status.dart';

class CaregiverDashboard extends ConsumerWidget {
  const CaregiverDashboard({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      title: const DashboardGreeting(),
      actions: const [DashboardUserMenu()],
    ),
    body: SafeArea(
      child: RefreshIndicator(
        onRefresh: () =>
            ref.read(caregiverUiRefreshProvider)?.refreshNow() ??
            Future.value(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Text(
                context.lang.setupFeatureNightscoutOverviewName,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const CaregiverRefreshStatus(),
            const CaregiverNightscoutPanel(),
          ],
        ),
      ),
    ),
  );
}

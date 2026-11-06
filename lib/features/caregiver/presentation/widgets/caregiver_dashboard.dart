import 'package:flutter/material.dart';

import '../../../dashboard/presentation/widgets/dashboard_greeting.dart';
import '../../../dashboard/presentation/widgets/dashboard_user_menu.dart';
import 'caregiver_data_error_notice.dart';
import 'caregiver_nightscout_panel.dart';

class CaregiverDashboard extends StatelessWidget {
  const CaregiverDashboard({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      title: const DashboardGreeting(),
      actions: const [DashboardUserMenu()],
    ),
    body: SafeArea(
      child: ListView(
        children: const [
          CaregiverDataErrorNotice(),
          CaregiverNightscoutPanel(),
        ],
      ),
    ),
  );
}

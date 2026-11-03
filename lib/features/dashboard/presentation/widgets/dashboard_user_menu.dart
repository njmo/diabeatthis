import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../../../../common/l10n/language.dart';

class DashboardUserMenu extends StatelessWidget {
  const DashboardUserMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.lang.settingsTitle,
      icon: const Icon(Icons.settings_outlined),
      onPressed: () => context.router.pushPath('/settings'),
    );
  }
}

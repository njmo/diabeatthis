import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/notifier_provider/simple_provider.dart';

class DashboardUserMenu extends ConsumerWidget {
  const DashboardUserMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(nameProvider).asData?.value.trim();
    return PopupMenuButton<String>(
      tooltip: context.lang.dashboardUserMenu,
      icon: const Icon(Icons.account_circle_outlined),
      position: PopupMenuPosition.under,
      onSelected: (_) => context.router.pushPath('/settings'),
      itemBuilder: (context) => [
        if (name != null && name.isNotEmpty)
          PopupMenuItem<String>(enabled: false, child: Text(name)),
        PopupMenuItem(
          value: 'settings',
          child: Row(
            children: [
              const Icon(Icons.settings_outlined),
              const SizedBox(width: 12),
              Text(context.lang.settingsTitle),
            ],
          ),
        ),
      ],
    );
  }
}

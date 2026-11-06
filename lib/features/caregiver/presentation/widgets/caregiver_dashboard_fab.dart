import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/anchored_fab_menu.dart';
import '../../../../common/widgets/fab_action_option.dart';

class CaregiverDashboardFab extends HookWidget {
  const CaregiverDashboardFab({
    super.key,
    required this.onMeal,
    required this.onActivity,
  });
  final VoidCallback onMeal;
  final VoidCallback onActivity;
  @override
  Widget build(BuildContext context) {
    final open = useState(false);
    return AnchoredFabMenu(
      open: open.value,
      onToggle: () => open.value = !open.value,
      onDismiss: () => open.value = false,
      actions: [
        if (open.value) ...[
          FabActionOption(
            icon: Icons.restaurant_outlined,
            label: context.lang.familyPlanMeal,
            onTap: () {
              open.value = false;
              onMeal();
            },
          ),
          const SizedBox(height: 8),
          FabActionOption(
            icon: Icons.directions_run,
            label: context.lang.familyPlanActivity,
            onTap: () {
              open.value = false;
              onActivity();
            },
          ),
        ],
      ],
    );
  }
}

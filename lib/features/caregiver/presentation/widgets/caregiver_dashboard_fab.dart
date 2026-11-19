import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/anchored_fab_menu.dart';
import '../../../../common/widgets/fab_action_option.dart';
import '../../../../common/widgets/responsive_metric_list.dart';

class CaregiverDashboardFab extends HookWidget {
  const CaregiverDashboardFab({
    super.key,
    required this.onPhoto,
    required this.onMeal,
    required this.onActivity,
  });
  final VoidCallback onPhoto;
  final VoidCallback onMeal;
  final VoidCallback onActivity;
  @override
  Widget build(BuildContext context) {
    final open = useState(false);
    void run(VoidCallback action) {
      open.value = false;
      action();
    }

    return AnchoredFabMenu(
      menuWidth: 360,
      open: open.value,
      onToggle: () => open.value = !open.value,
      onDismiss: () => open.value = false,
      actions: [
        if (open.value) ...[
          FabActionOption(
            tile: true,
            horizontal: true,
            icon: Icons.add_a_photo_outlined,
            label: context.lang.mealPhotoTitle,
            onTap: () => run(onPhoto),
          ),
          const SizedBox(height: 8),
          ResponsiveMetricList(
            maxColumns: 2,
            spacing: 8,
            runSpacing: 8,
            children: [
              FabActionOption(
                tile: true,
                accent: Theme.of(context).colorScheme.primary,
                icon: Icons.restaurant_outlined,
                label: context.lang.familyPlanMeal,
                onTap: () => run(onMeal),
              ),
              FabActionOption(
                tile: true,
                accent: const Color(0xFF62CBB2),
                icon: Icons.directions_run,
                label: context.lang.familyPlanActivity,
                onTap: () => run(onActivity),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

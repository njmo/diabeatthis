import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../app/router/app_router.dart' as routes;
import '../../../../common/widgets/fab_action_option.dart';
import '../../../meals/data/providers/meal_draft_provider.dart';

class ParentDashboardFAB extends HookConsumerWidget {
  const ParentDashboardFAB({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = useState(false);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (open.value) ...[
          FabActionOption(
            icon: Icons.note_alt,
            label: 'Dodaj notatkę',
            onTap: () {
              open.value = false;
            },
          ),
          const SizedBox(height: 8),
          FabActionOption(
            icon: Icons.restaurant,
            label: 'Zaplanuj posiłek',
            onTap: () {
              ref.read(mealDraftProvider.notifier).reset();
              context.router.push(routes.AddMealRoute());
              open.value = false;
            },
          ),
          const SizedBox(height: 8),
          FabActionOption(
            icon: Icons.post_add,
            label: 'Dodaj szablon',
            onTap: () {
              context.router.push(routes.AddMealTemplateRoute());
              open.value = false;
            },
          ),
          const SizedBox(height: 16),
        ],
        FloatingActionButton(
          onPressed: () => open.value = !open.value,
          child: Icon(open.value ? Icons.close : Icons.add),
        ),
      ],
    );
  }
}

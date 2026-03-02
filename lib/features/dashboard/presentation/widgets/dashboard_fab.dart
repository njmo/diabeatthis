import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../app/router/app_router.dart' as routes;
import '../../../../core/data/provider/parent_controller_provider.dart';
import '../../../../core/domain/model/activity.dart';
import '../../../activity/data/providers/activity_provider.dart';
import '../../../activity/presentation/widgets/activity_form.dart';
import '../../../activity/presentation/widgets/activity_picker_dialog.dart';
import '../../../activity/presentation/widgets/activity_search.dart';
import '../../../meals/data/drafts/meal_draft.dart';
import '../../../meals/data/providers/meal_database_provider.dart';
import '../../../meals/data/providers/meal_draft_provider.dart';
import '../../../meals/presentation/widgets/add_meal_ingredient.dart';
import '../../data/providers/meal_add_provider.dart';
import 'meal_status_dialog.dart';

class DashboardFAB extends HookConsumerWidget {
  const DashboardFAB({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var open = useState(false);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (open.value) ...[
          _buildOption(Icons.note_alt, 'Add note', () {
            open.value = false;
          }),
          const SizedBox(height: 8),
          _buildOption(Icons.sports, 'Start activity', () async {
            final activity = await showDialog<Activity?>(
              barrierDismissible: true,
              context: context,
              builder: (context) => ActivityPickerDialog(),
            );
            if (activity != null) {
              activity.when(
                existing: (id, name) =>
                    print('Starting existing id: $id, name: $name'),
                draft: (name) => {
                  ref.read(insertActivityProvider(Activity.draft(name: name))),
                },
              );
            }
            open.value = false;
          }),
          const SizedBox(height: 8),
          _buildOption(Icons.restaurant, 'Plan meal', () {
            context.router.push(routes.AddMealRoute());
            open.value = false;
          }),
          const SizedBox(height: 16),
        ],
        FloatingActionButton(
          onPressed: () => open.value = !open.value,
          child: Icon(open.value ? Icons.close : Icons.add),
        ),
      ],
    );
  }

  Widget _buildOption(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.black87),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.black87)),
          ],
        ),
      ),
    );
  }
}

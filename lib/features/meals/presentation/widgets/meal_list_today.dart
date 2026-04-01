import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../app/router/app_router.dart' as routes;
import '../../../../core/data/provider/parent_controller_provider.dart';
import '../../../dashboard/presentation/widgets/meal_status_dialog.dart';
import '../../../dashboard/presentation/widgets/trailing_wait_after_bolus_status.dart';
import '../../data/providers/meal_database_provider.dart';

class MealListToday extends ConsumerWidget {
  const MealListToday({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meals = ref.watch(plannedMealsForTodayStreamProvider);
    final parentModeEnabled = ref.watch(parentModeProvider);

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: ListView.builder(
        itemBuilder: (context, index) {
          final meal = meals.asData?.value[index];
          if (meal == null) {
            return SizedBox.shrink();
          }

          return InkWell(
            onTap: () async {
              if (meal.status == 'eaten' || meal.status == 'eaten-bolused') {
                context.router.push(routes.MealSummaryRoute(mealId: meal.id));
                return;
              }
              final action = await showDialog<String?>(
                barrierDismissible: true,
                context: context,
                builder: (context) => MealStatusDialog(meal: meal),
              );
              if (action != null) {
                await ref.read(updateMealProvider(meal, action).future);
              }
            },
            child: Card(
              elevation: 2,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: ListTile(
                title: Text(
                  meal.name,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w400),
                ),
                subtitle: Align(
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      _buildListTile(
                        _shortTime(meal.plannedAt!),
                        Icons.access_time,
                        Theme.of(context).colorScheme,
                      ),
                      const SizedBox(width: 10),
                      _buildListTile(
                        _toMealStatus(meal.status),
                        Icons.note_rounded,
                        Theme.of(context).colorScheme,
                      ),
                    ],
                  ),
                ),
                trailing: (parentModeEnabled)
                    ? IconButton(
                        onPressed: () {
                          ref.read(removeMealByIdProvider(meal));
                        },
                        icon: Icon(Icons.remove_circle),
                        iconSize: 20,
                      )
                    : (meal.status == 'bolused-waiting')
                    ? TrailingWaitAfterBolusStatus(meal: meal)
                    : const SizedBox.shrink(),
              ),
            ),
          );
        },
        itemCount: meals.asData?.value.length ?? 0,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
      ),
    );
  }

  Widget _buildListTile(String text, IconData icon, ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: scheme.onSecondaryContainer),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: scheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  String _toMealStatus(String? status) {
    switch (status) {
      case 'eaten':
      case 'eaten-bolused':
        return 'Zjedzony';
      case 'skipped':
        return 'Pominięty';
      case 'waited-eating':
      case 'bolused-eating':
      case 'eating':
      case 'eating-then-bolus':
        return 'W trakcie jedzenia';
      case 'bolused-waiting':
        return 'Oczekuje na zjedzenie';
      default:
        return 'Zaplanowany';
    }
  }

  String _shortTime(DateTime? dt) {
    if (dt == null) return "—";
    final t = TimeOfDay.fromDateTime(dt);
    return "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";
  }
}

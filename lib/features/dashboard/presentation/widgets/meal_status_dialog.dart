import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/domain/model/meal.dart';
import '../../data/meal_dialog_controller.dart';
import '../../data/meal_dialog_state.dart';

class MealStatusDialog extends ConsumerWidget {
  final Meal meal;
  const MealStatusDialog({required this.meal, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(mealDialogControllerProvider(meal.id));
    final c = ref.read(mealDialogControllerProvider(meal.id).notifier);

    Widget content() {
      switch (s.step) {
        case MealDialogStep.choose:
          return Padding(
            padding: EdgeInsetsGeometry.directional(top: 10),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: EdgeInsetsGeometry.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.rectangle,
                      borderRadius: BorderRadius.all(Radius.circular(15)),
                      color: Colors.white70,
                    ),
                    child: InkWell(
                      onTap: c.chooseEat,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.restaurant_outlined, size: 60),
                          Text('Eat'),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 20),
                Expanded(
                  child: Container(
                    padding: EdgeInsetsGeometry.all(10),
                    decoration: BoxDecoration(
                      shape: BoxShape.rectangle,
                      borderRadius: BorderRadius.all(Radius.circular(15)),
                      color: Colors.white70,
                    ),
                    child: InkWell(
                      onTap: c.chooseSkip,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.no_meals, size: 60),
                          Text('Skip'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        case MealDialogStep.details:
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text("Dane posiłku"),
              Text(
                "Proste weglowodany ${s.carbsGrams.toStringAsFixed(0)}g",
              ),
              if (s.extendedCarbsGrams != 0) Text(
                "Przedluzone weglowowany ${s.extendedCarbsGrams.toStringAsFixed(0)}g",
              ),
              const SizedBox(height: 12),
            ],
          );

        case MealDialogStep.confirm:
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                s.skipMeal
                    ? "Potwierdź pominięcie posiłku"
                    : "Potwierdź posiłek",
              ),
              const SizedBox(height: 12),
              if (s.skipMeal)
                const Text("Zapiszemy, że posiłek został pominięty.")
              else
                Text(
                  "Stan: ${s.mealState}\nWęgle: ${s.carbsGrams.toStringAsFixed(0)} g\n${s.waitHint}",
                ),
            ],
          );
      }
    }

    List<Widget> actions() {
      switch (s.step) {
        case MealDialogStep.choose:
          return [const SizedBox.shrink()];
        case MealDialogStep.details:
          return [
            TextButton(onPressed: c.back, child: const Text("Wstecz")),
            TextButton(onPressed: c.next, child: const Text("Dalej")),
          ];
        case MealDialogStep.confirm:
          return [
            TextButton(onPressed: c.back, child: const Text("Wstecz")),
            ElevatedButton(
              onPressed: () async {
                await c.save();
                if (context.mounted) {
                  if (s.skipMeal) {
                    Navigator.of(context).pop('skipped');
                  } else {
                    Navigator.of(context).pop('eaten');
                  }
                }
              },
              child: const Text("Zapisz"),
            ),
          ];
      }
    }

    return AlertDialog(
      title: Text(meal.name),
      content: content(),
      actions: actions(),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/domain/model/meal.dart';
import '../../data/meal_dialog_controller.dart';
import '../../data/meal_dialog_state.dart';
import '../../data/utils/meal_advisor.dart';

class MealStatusDialog extends ConsumerWidget {
  final Meal meal;
  const MealStatusDialog({required this.meal, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(mealDialogControllerProvider(meal.id, getStep()));
    final c = ref.read(
      mealDialogControllerProvider(meal.id, getStep()).notifier,
    );

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
                          Text('Zjem'),
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
                          Text('Pomijam'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        case MealDialogStep.confirm:
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if(s.skipMeal) const Text("Potwierdź pominięcie posiłku"),
              if (s.skipMeal)
                const Text("Zapiszemy, że posiłek został pominięty.")
              else if (s.advice.decision != null)
                Text("Propozycja do wykonania: \n\n${c.mealAdviceString()}\n"),
            ],
          );
        case MealDialogStep.confirmEaten:
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [Text('Potwierdź że posiłek został zjedzony')],
          );
        case MealDialogStep.confirmEating:
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [Text('Potwierdź że zacząłeś jeść')],
          );
        case MealDialogStep.confirmBolusedAfterEating:
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [Text('Potwierdź że podałeś insuline po zjedzeniu')],
          );
      }
    }

    List<Widget> actions() {
      switch (s.step) {
        case MealDialogStep.choose:
          return [const SizedBox.shrink()];
        case MealDialogStep.confirm:
          return [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Anuluj"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (context.mounted) {
                  if (s.skipMeal) {
                    Navigator.of(context).pop('skipped');
                  } else {
                    Navigator.of(context).pop(s.advice.decision!.status);
                  }
                }
              },
              child: Text(_buttonText(s.advice.decision!.status)),
            ),
          ];
        case MealDialogStep.confirmEaten:
          return [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Anuluj"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (context.mounted) {
                  Navigator.of(context).pop('eaten');
                }
                ;
              },
              child: const Text("Zjadłem"),
            ),
          ];

        case MealDialogStep.confirmEating:
          return [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Anuluj"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (context.mounted) {
                  Navigator.of(context).pop('eating');
                }
              },
              child: const Text("Jem"),
            ),
          ];
        case MealDialogStep.confirmBolusedAfterEating:
          return [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Anuluj"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (context.mounted) {
                  Navigator.of(context).pop('eaten-bolused');
                }
                ;
              },
              child: const Text("Podałem insuline"),
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

  String _buttonText(String? status) {
    switch (status) {
      case 'eating-then-bolus':
        return "Zaczynam jeść";
      case 'bolused-eating':
        return "Podaje bolusa";
      case 'bolused-waiting':
        return "Podaje bolusa i czekam";
    }
    return '';
  }

  MealDialogStep getStep() {
    switch (meal.status) {
      case 'bolused-waiting':
        return MealDialogStep.confirmEating;
      case 'eating-then-bolus':
        return MealDialogStep.confirmBolusedAfterEating;
      case 'waited-eating':
      case 'bolused-eating':
      case 'eating':
        return MealDialogStep.confirmEaten;
      default:
        return MealDialogStep.choose;
    }
  }
}

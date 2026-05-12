import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/widgets/bottom_sheet_step_header.dart';
import '../../../../common/widgets/keyboard_aware_bottom_sheet.dart';
import '../../../ingredients/data/providers/ingredient_provider.dart';
import '../../../ingredients/presentation/widgets/ingredient_form.dart';
import '../../../ingredients/presentation/widgets/ingredient_photo_scan.dart';
import '../../../ingredients/presentation/widgets/ingredient_portion_amount_form.dart';
import '../../../ingredients/presentation/widgets/ingredient_search.dart';
import '../../../portions/data/providers/portion_provider.dart';
import '../../../portions/presentation/widgets/portion_form.dart';
import '../../../portions/presentation/widgets/portion_search.dart';
import '../../data/providers/add_ingredients_provider.dart';
import '../../data/providers/meal_draft_provider.dart';
import 'amount_form.dart';
import 'summary.dart';

class AddMealIngredient extends ConsumerWidget {
  const AddMealIngredient({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(portionFilterProvider);
    ref.watch(ingredientDraftProvider);
    final addingStage = ref.watch(addMealIngredientStageProvider);
    final addingStateNotifier = ref.read(
      addMealIngredientStageProvider.notifier,
    );

    return KeyboardAwareBottomSheet(
      header: switch (addingStage) {
        AddMealIngredientStage.ingredientSearch => BottomSheetStepHeader(
          title: 'Wyszukaj składnik',
          onBack: addingStateNotifier.back,
          actions: [
            IconButton(
              tooltip: 'Dodaj ręcznie',
              onPressed: addingStateNotifier.startManualIngredient,
              icon: const Icon(Icons.add_box_outlined),
            ),
            IconButton(
              tooltip: 'Dodaj ze zdjęć',
              onPressed: addingStateNotifier.startIngredientPhotoScan,
              icon: const Icon(Icons.add_a_photo_outlined),
            ),
          ],
        ),
        AddMealIngredientStage.ingredientPhotoScan => BottomSheetStepHeader(
          title: 'Dodaj ze zdjęć',
          onBack: addingStateNotifier.back,
        ),
        AddMealIngredientStage.ingredientForm => BottomSheetStepHeader(
          title: 'Dodaj składnik',
          onBack: addingStateNotifier.back,
          actions: [
            IconButton(
              tooltip: 'Wyszukaj składnik',
              onPressed: addingStateNotifier.toOppositeStage,
              icon: const Icon(Icons.search),
            ),
          ],
        ),
        AddMealIngredientStage.portionAddNewSearch => BottomSheetStepHeader(
          title: 'Wybierz porcję dla składnika',
          onBack: addingStateNotifier.back,
          actions: [
            IconButton(
              tooltip: 'Dodaj porcję',
              onPressed: addingStateNotifier.toOppositeStage,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        AddMealIngredientStage.definedPortionsSearch => BottomSheetStepHeader(
          title: 'Wyszukaj istniejącą porcję',
          onBack: addingStateNotifier.back,
          actions: [
            IconButton(
              tooltip: 'Dodaj porcję',
              onPressed: addingStateNotifier.toOppositeStage,
              icon: const Icon(Icons.add_box_outlined),
            ),
          ],
        ),
        AddMealIngredientStage.amountForm => const Text('Ilość'),
        AddMealIngredientStage.summary => const Text('Podsumowanie'),
        AddMealIngredientStage.portionSpecifyAmount => const Text(
          'Waga składnika w porcji',
        ),
        AddMealIngredientStage.portionAddNewForm => BottomSheetStepHeader(
          title: 'Dodaj nową porcję',
          onBack: addingStateNotifier.back,
          actions: [
            IconButton(
              tooltip: 'Wyszukaj porcję',
              onPressed: addingStateNotifier.toOppositeStage,
              icon: const Icon(Icons.search),
            ),
          ],
        ),
      },
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: switch (addingStage) {
          AddMealIngredientStage.ingredientSearch => IngredientSearch(),
          AddMealIngredientStage.ingredientPhotoScan => IngredientPhotoScan(),
          AddMealIngredientStage.ingredientForm => IngredientForm(),
          AddMealIngredientStage.portionAddNewSearch => PortionSearch(),
          AddMealIngredientStage.definedPortionsSearch => PortionSearch(),
          AddMealIngredientStage.amountForm => AmountForm(),
          AddMealIngredientStage.summary => AddIngredientSummary(),
          AddMealIngredientStage.portionSpecifyAmount =>
            IngredientPortionAmountForm(),
          AddMealIngredientStage.portionAddNewForm => PortionForm(),
        },
      ),
      actions: Row(
        children: [
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                if (addingStage == AddMealIngredientStage.summary) {
                  Navigator.of(
                    context,
                  ).pop(ref.read(mealIngredientsDraftProvider));
                } else if (addingStage ==
                    AddMealIngredientStage.ingredientPhotoScan) {
                  addingStateNotifier.nextStage();
                } else {
                  final formKey = ref.read(mealIngredientFormKeyProvider);
                  if (formKey.currentState!.validate()) {
                    addingStateNotifier.nextStage();
                    formKey.currentState!.reset();
                  }
                }
              },
              child: (addingStage == AddMealIngredientStage.summary)
                  ? const Text('Dodaj')
                  : Text(
                      addingStage == AddMealIngredientStage.ingredientPhotoScan
                          ? 'Symuluj odczyt'
                          : 'Dalej',
                    ),
            ),
          ),
          addingStage != AddMealIngredientStage.definedPortionsSearch &&
                  addingStage != AddMealIngredientStage.portionAddNewSearch
              ? SizedBox.shrink()
              : Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      addingStateNotifier.setOverride();
                    },
                    child: const Text('Dodaj w gramach'),
                  ),
                ),
          addingStage != AddMealIngredientStage.summary
              ? SizedBox.shrink()
              : Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final result = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Odrzucić zmiany?'),
                          content: const Text(
                            'Czy na pewno chcesz odrzucić zmiany?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop(true);
                              },
                              child: const Text('Tak'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(context).pop(false);
                              },
                              child: const Text('Nie'),
                            ),
                          ],
                        ),
                      );
                      if (result == true) {
                        if (context.mounted) {
                          Navigator.of(context).pop();
                        }
                      }
                    },
                    child: const Text('Odrzuć'),
                  ),
                ),
        ],
      ),
    );
  }
}

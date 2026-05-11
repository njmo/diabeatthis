import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../meal_template/data/provider/meal_template_ingredients_list_provider.dart';
import '../../data/model/copied_meal_type.dart';
import '../../data/providers/meal_draft_provider.dart';
import '../../data/providers/meal_ingredients_list_provider.dart';
import '../controllers/add_meal_controller.dart';
import '../widgets/add_meal/add_meal_basic_info_section.dart';
import '../widgets/add_meal/add_meal_ingredients_section.dart';
import '../widgets/add_meal/add_meal_source_section.dart';
import '../widgets/copied_meal_picker.dart';

@RoutePage()
class AddMealPage extends HookConsumerWidget {
  const AddMealPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formKey = useMemoized(GlobalKey<FormState>.new);
    final mealDraft = ref.read(mealDraftProvider.notifier);
    final addMealState = ref.watch(addMealControllerProvider);
    final isSaving = addMealState.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Dodaj posiłek')),
      body: SafeArea(
        child: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              AddMealBasicInfoSection(
                onNameSaved: mealDraft.setName,
                onPlannedAtSaved: mealDraft.setPlannedAt,
              ),
              const SizedBox(height: 24),
              AddMealSourceSection(
                picker: showCopiedMealPicker,
                onPicked: (value) => _copyIngredientsFromSource(ref, value),
                onSaved: (value) => _saveSource(ref, value),
              ),
              const SizedBox(height: 24),
              const AddMealIngredientsSection(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FilledButton.icon(
          onPressed: isSaving
              ? null
              : () => _saveMeal(context: context, ref: ref, formKey: formKey),
          icon: isSaving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: Text(isSaving ? 'Zapisywanie...' : 'Zapisz posiłek'),
        ),
      ),
    );
  }

  Future<CopiedMealType?> showCopiedMealPicker(BuildContext context) {
    return showModalBottomSheet<CopiedMealType>(
      useRootNavigator: false,
      isScrollControlled: true,
      context: context,
      builder: (context) => const CopiedMealPicker(),
    );
  }

  Future<void> _copyIngredientsFromSource(
    WidgetRef ref,
    CopiedMealType? value,
  ) async {
    if (value is CopiedMealFromTemplate) {
      final ingredients = await ref.read(
        getMealIngredientsDraftForMealTemplateProvider(value.id).future,
      );
      final draft = ref.read(mealDraftProvider.notifier);
      draft.clearMealIngredients();
      draft.addMealIngredients(ingredients);
    } else if (value is CopiedMealFromMeal) {
      final ingredients = await ref.read(
        getMealIngredientsDraftForMealProvider(value.id).future,
      );
      final draft = ref.read(mealDraftProvider.notifier);
      draft.clearMealIngredients();
      draft.addMealIngredients(ingredients);
    }
  }

  void _saveSource(WidgetRef ref, CopiedMealType? value) {
    final draft = ref.read(mealDraftProvider.notifier);
    if (value?.copiedFromMealId != null ||
        value?.copiedFromTemplateId != null) {
      draft.setBasedOnMealId(value!.copiedFromMealId);
      draft.setMealTemplateId(value.copiedFromTemplateId);
    } else if (value is CopiedMealFromTemplate) {
      draft.setMealTemplateId(value.id);
    } else if (value is CopiedMealFromMeal) {
      draft.setBasedOnMealId(value.id);
    }
  }

  Future<void> _saveMeal({
    required BuildContext context,
    required WidgetRef ref,
    required GlobalKey<FormState> formKey,
  }) async {
    final formState = formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    formState.save();
    final updatedDraft = ref.read(mealDraftProvider);

    try {
      await ref.read(addMealControllerProvider.notifier).addMeal(updatedDraft);
      if (context.mounted) {
        context.router.pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nie udało się dodać posiłku: $e')),
        );
      }
    }
  }
}

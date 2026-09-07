import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../data/model/copied_meal_type.dart';
import '../../data/providers/meal_draft_provider.dart';
import '../controllers/add_meal_controller.dart';
import '../controllers/copy_meal_source_controller.dart';
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
    final isCopying = ref.watch(copyMealSourceControllerProvider).isLoading;
    final copyController = ref.read(copyMealSourceControllerProvider.notifier);
    useEffect(() => copyController.cancelPendingCopy, [copyController]);

    return Scaffold(
      appBar: AppBar(title: Text(context.lang.addMealTitle)),
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
                isLoading: isCopying,
                enabled: !isSaving,
                onPicked: (value) => _copyFromSource(context, ref, value),
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
          onPressed: isSaving || isCopying
              ? null
              : () => _saveMeal(context: context, ref: ref, formKey: formKey),
          icon: isSaving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: Text(
            isSaving ? context.lang.addMealSaving : context.lang.addMealSave,
          ),
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

  Future<bool> _copyFromSource(
    BuildContext context,
    WidgetRef ref,
    CopiedMealType source,
  ) async {
    try {
      return await ref
          .read(copyMealSourceControllerProvider.notifier)
          .copyFromSource(source);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.lang.mealIngredientsLoadError(error))),
        );
      }
      return false;
    }
  }

  Future<void> _saveMeal({
    required BuildContext context,
    required WidgetRef ref,
    required GlobalKey<FormState> formKey,
  }) async {
    if (ref.read(copyMealSourceControllerProvider).isLoading) {
      return;
    }
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
          SnackBar(content: Text(context.lang.addMealSaveError(e))),
        );
      }
    }
  }
}

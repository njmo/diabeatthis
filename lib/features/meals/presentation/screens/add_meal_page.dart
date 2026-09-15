import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../data/model/copied_meal_type.dart';
import '../../data/models/retrospective_meal_timing.dart';
import '../../data/providers/meal_draft_provider.dart';
import '../controllers/add_meal_controller.dart';
import '../controllers/copy_meal_source_controller.dart';
import '../widgets/add_meal/add_meal_basic_info_section.dart';
import '../widgets/add_meal/add_meal_ingredients_section.dart';
import '../widgets/add_meal/add_meal_source_section.dart';
import '../widgets/add_meal/retrospective_meal_fields.dart';
import '../widgets/copied_meal_picker.dart';

@RoutePage()
class AddMealPage extends HookConsumerWidget {
  final bool retrospective;
  final DateTime? initialEatenAt;
  const AddMealPage({
    super.key,
    this.retrospective = false,
    this.initialEatenAt,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timing = useState(const RetrospectiveMealTiming());
    final formKey = useMemoized(GlobalKey<FormState>.new);
    final mealDraft = ref.read(mealDraftProvider.notifier);
    final addMealState = ref.watch(addMealControllerProvider);
    final isSaving = addMealState.isLoading;
    final isCopying = ref.watch(copyMealSourceControllerProvider).isLoading;
    final copyController = ref.read(copyMealSourceControllerProvider.notifier);
    useEffect(() => copyController.cancelPendingCopy, [copyController]);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          retrospective
              ? context.lang.uiRecordAPastMeal
              : context.lang.addMealTitle,
        ),
      ),
      body: SafeArea(
        child: Form(
          key: formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AddMealBasicInfoSection(
                  retrospective: retrospective,
                  initialEatenAt: initialEatenAt,
                  onNameSaved: mealDraft.setName,
                  onPlannedAtChanged: mealDraft.setPlannedAt,
                ),
                const SizedBox(height: 24),
                AddMealSourceSection(
                  picker: (context) => showCopiedMealPicker(context, ref),
                  isLoading: isCopying,
                  enabled: !isSaving,
                  onPicked: (value) => _copyFromSource(context, ref, value),
                ),
                const SizedBox(height: 24),
                const AddMealIngredientsSection(),
                if (retrospective) ...[
                  const SizedBox(height: 24),
                  RetrospectiveMealFields(
                    value: timing.value,
                    onChanged: (value) => timing.value = value,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: FilledButton.icon(
          onPressed: isSaving || isCopying
              ? null
              : () => _saveMeal(
                  context: context,
                  ref: ref,
                  formKey: formKey,
                  timing: retrospective ? timing.value : null,
                ),
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

  Future<CopiedMealType?> showCopiedMealPicker(
    BuildContext context,
    WidgetRef ref,
  ) {
    return showModalBottomSheet<CopiedMealType>(
      useRootNavigator: false,
      isScrollControlled: true,
      context: context,
      builder: (context) => CopiedMealPicker(
        initialQuery: ref.read(mealDraftProvider).name.trim(),
      ),
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
    RetrospectiveMealTiming? timing,
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
      final meal = await ref
          .read(addMealControllerProvider.notifier)
          .addMeal(updatedDraft, retrospective: timing);
      if (context.mounted) {
        context.router.pop(meal);
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

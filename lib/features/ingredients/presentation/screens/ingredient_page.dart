import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../meals/data/providers/add_ingredients_provider.dart';
import '../../data/models/ingredient_portion_data.dart';
import '../../data/providers/ingredient_provider.dart';
import '../controllers/ingredient_details_controller.dart';
import '../models/ingredient_page_state.dart';
import '../widgets/ingredient_detail_sections.dart';
import '../widgets/ingredient_details_view.dart';
import '../widgets/ingredient_edit_mode.dart';
import '../widgets/ingredient_portion_amount_form.dart';

@RoutePage()
class IngredientPage extends ConsumerWidget {
  final int ingredientId;

  const IngredientPage({super.key, required this.ingredientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(ingredientDraftProvider.notifier);
    final state = ref.watch(ingredientDetailsControllerProvider(ingredientId));
    final bottomPadding = 16 + MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(
        title: state.maybeWhen(
          data: (s) => Text(s.data.ingredient.name),
          orElse: () => Text('Składnik $ingredientId'),
        ),
        actions: state.maybeWhen(
          data: (s) => _appBarActions(context, ref, s),
          orElse: () => const [],
        ),
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('error: $e')),
        data: (s) {
          if (s.isEditing) {
            ref.listen(ingredientPortionAmountDraftProvider, (_, _) {});
          }
          final canEditPortions =
              s.isEditing && !s.isSaving && !s.data.ingredient.isReference;

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (s.isEditing)
                  const IngredientEditMode()
                else
                  IngredientDetailsView(data: s.data),
                const SizedBox(height: 24),
                IngredientHistorySection(history: s.data.history),
                const SizedBox(height: 24),
                IngredientPortionsSection(
                  portions: s.data.portions,
                  onEdit: canEditPortions
                      ? (portion) => _editPortionAmount(context, ref, portion)
                      : null,
                ),
                const SizedBox(height: 24),
                IngredientMealsSection(usages: s.data.usages),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _appBarActions(
    BuildContext context,
    WidgetRef ref,
    IngredientPageState state,
  ) {
    final controller = ref.read(
      ingredientDetailsControllerProvider(ingredientId).notifier,
    );

    if (!state.isEditing) {
      return [
        IconButton(
          tooltip: 'Edytuj składnik',
          icon: const Icon(Icons.edit),
          onPressed: state.isSaving ? null : controller.startEditing,
        ),
      ];
    }

    return [
      IconButton(
        tooltip: 'Anuluj edycję',
        icon: const Icon(Icons.close),
        onPressed: state.isSaving ? null : controller.cancelEditing,
      ),
      IconButton(
        tooltip: 'Zapisz składnik',
        onPressed: state.isSaving ? null : () => _saveIngredient(context, ref),
        icon: state.isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.check),
      ),
    ];
  }

  Future<void> _saveIngredient(BuildContext context, WidgetRef ref) async {
    final formKey = ref.read(mealIngredientFormKeyProvider);
    if (!(formKey.currentState?.validate() ?? false)) {
      return;
    }

    try {
      await ref
          .read(ingredientDetailsControllerProvider(ingredientId).notifier)
          .save();
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Składnik zapisany')));
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się zapisać składnika: $e')),
      );
    }
  }

  Future<void> _editPortionAmount(
    BuildContext context,
    WidgetRef ref,
    IngredientPortionData portion,
  ) async {
    ref
        .read(ingredientPortionAmountDraftProvider.notifier)
        .setValue(portion.gramsPerPortion);
    final amount = await showIngredientPortionAmountSheet(context: context);
    if (amount == null || amount == portion.gramsPerPortion) {
      return;
    }

    try {
      await ref
          .read(ingredientDetailsControllerProvider(ingredientId).notifier)
          .updatePortionAmount(
            portionId: portion.portionId,
            gramsPerPortion: amount,
          );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Porcja zapisana')));
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Nie udało się zapisać porcji: $e')),
      );
    }
  }
}

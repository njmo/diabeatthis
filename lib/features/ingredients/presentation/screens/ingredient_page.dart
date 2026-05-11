import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/ingredient_edit_draft.dart';
import '../controllers/ingredient_details_controller.dart';
import '../widgets/ingredient_detail_sections.dart';
import '../widgets/ingredient_details_view.dart';
import '../widgets/ingredient_edit_mode.dart';

@RoutePage()
class IngredientPage extends ConsumerWidget {
  final int ingredientId;

  const IngredientPage({super.key, required this.ingredientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ingredientDetailsControllerProvider(ingredientId));
    final bottomPadding = 16 + MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      appBar: AppBar(
        title: state.maybeWhen(
          data: (s) => Text(s.data.ingredient.name),
          orElse: () => Text('Składnik $ingredientId'),
        ),
        actions: [
          state.maybeWhen(
            data: (s) {
              if (s.isEditing) {
                return const SizedBox.shrink();
              }
              return IconButton(
                tooltip: 'Edytuj składnik',
                icon: const Icon(Icons.edit),
                onPressed: s.isSaving
                    ? null
                    : () => ref
                          .read(
                            ingredientDetailsControllerProvider(
                              ingredientId,
                            ).notifier,
                          )
                          .startEditing(),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('error: $e')),
        data: (s) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (s.isEditing)
                IngredientEditMode(
                  ingredient: s.data.ingredient,
                  isSaving: s.isSaving,
                  onCancel: () => ref
                      .read(
                        ingredientDetailsControllerProvider(
                          ingredientId,
                        ).notifier,
                      )
                      .cancelEditing(),
                  onSave: (draft) => _saveDraft(context, ref, draft),
                )
              else
                IngredientDetailsView(data: s.data),
              const SizedBox(height: 24),
              IngredientHistorySection(history: s.data.history),
              const SizedBox(height: 24),
              IngredientPortionsSection(portions: s.data.portions),
              const SizedBox(height: 24),
              IngredientMealsSection(usages: s.data.usages),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveDraft(
    BuildContext context,
    WidgetRef ref,
    IngredientEditDraft draft,
  ) async {
    try {
      await ref
          .read(ingredientDetailsControllerProvider(ingredientId).notifier)
          .save(draft);
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
}

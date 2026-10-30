import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../meals/data/providers/add_ingredients_provider.dart';
import '../../data/models/ingredient_portion_data.dart';
import '../../data/providers/ingredient_provider.dart';
import '../controllers/ingredient_details_controller.dart';
import '../widgets/ingredient_details_header.dart';
import '../widgets/ingredient_edit_actions.dart';
import '../widgets/ingredient_edit_mode.dart';
import '../widgets/ingredient_history_section.dart';
import '../widgets/ingredient_meals_section.dart';
import '../widgets/ingredient_nutrition_card.dart';
import '../widgets/ingredient_portion_amount_form.dart';
import '../widgets/ingredient_portions_section.dart';

@RoutePage()
class IngredientPage extends ConsumerStatefulWidget {
  const IngredientPage({super.key, required this.ingredientId});

  final int ingredientId;

  @override
  ConsumerState<IngredientPage> createState() => IngredientPageViewState();
}

class IngredientPageViewState extends ConsumerState<IngredientPage>
    with SingleTickerProviderStateMixin {
  late final TabController tabs;
  int get ingredientId => widget.ingredientId;

  @override
  void initState() {
    super.initState();
    tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(ingredientDraftProvider.notifier);
    final state = ref.watch(ingredientDetailsControllerProvider(ingredientId));
    final current = state.asData?.value;
    final controller = ref.read(
      ingredientDetailsControllerProvider(ingredientId).notifier,
    );
    final colors = Theme.of(context).colorScheme;
    Widget scroll(Widget child) => SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: child,
    );
    return PopScope(
      canPop: current?.isEditing != true,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && current?.isEditing == true) controller.cancelEditing();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: current?.isEditing == true
              ? IconButton(
                  tooltip: context.lang.ingredientCancelEditTooltip,
                  onPressed: current!.isSaving
                      ? null
                      : controller.cancelEditing,
                  icon: const Icon(Icons.arrow_back),
                )
              : null,
          title: Text(
            current?.isEditing == true
                ? current!.data.ingredient.isReference
                      ? context.lang.ingredientReferenceEditTitle
                      : context.lang.ingredientEditTitle
                : current?.data.ingredient.isReference == true
                ? context.lang.ingredientReferenceBadge
                : context.lang.ingredientDetailsTitle,
          ),
          actions: [
            if (current != null && !current.isEditing)
              TextButton.icon(
                onPressed: current.isSaving
                    ? null
                    : () {
                        tabs.index = 0;
                        controller.startEditing();
                      },
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(context.lang.ingredientEditAction),
              ),
          ],
        ),
        bottomNavigationBar: current?.isEditing == true
            ? IngredientEditActions(
                isSaving: current!.isSaving,
                onCancel: controller.cancelEditing,
                onSave: () => _saveIngredient(context, ref),
              )
            : null,
        body: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text(context.lang.activityError(e))),
          data: (s) {
            if (s.isEditing) {
              ref.listen(ingredientPortionAmountDraftProvider, (_, _) {});
              return scroll(
                AbsorbPointer(
                  absorbing: s.isSaving,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      IngredientEditMode(
                        onIconSelected: controller.onIconSelected,
                      ),
                      const SizedBox(height: 16),
                      IngredientPortionsSection(
                        portions: s.data.portions,
                        onEdit: !s.data.ingredient.isReference && !s.isSaving
                            ? (portion) =>
                                  _editPortionAmount(context, ref, portion)
                            : null,
                      ),
                    ],
                  ),
                ),
              );
            }
            return NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: IngredientDetailsHeader(
                      ingredient: s.data.ingredient,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TabBar(
                      controller: tabs,
                      labelColor: colors.primary,
                      labelStyle: Theme.of(context).textTheme.labelLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                      unselectedLabelColor: colors.onSurfaceVariant,
                      indicatorSize: TabBarIndicatorSize.tab,
                      splashBorderRadius: BorderRadius.circular(18),
                      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                      indicator: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      indicatorPadding: const EdgeInsets.symmetric(vertical: 4),
                      dividerColor: Colors.transparent,
                      tabs: [
                        Tab(text: context.lang.ingredientDataTab),
                        Tab(text: context.lang.ingredientMealsTab),
                        Tab(text: context.lang.ingredientHistoryTab),
                      ],
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                controller: tabs,
                children: [
                  scroll(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        IngredientNutritionCard(ingredient: s.data.ingredient),
                        const SizedBox(height: 16),
                        IngredientPortionsSection(portions: s.data.portions),
                      ],
                    ),
                  ),
                  scroll(IngredientMealsSection(usages: s.data.usages)),
                  scroll(
                    IngredientHistorySection(
                      history: s.data.history,
                      ingredient: s.data.ingredient,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _saveIngredient(BuildContext context, WidgetRef ref) async {
    final formKey = ref.read(ingredientFormKeyProvider);
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
      tabs.index = 0;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.lang.ingredientSaved)));
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.lang.ingredientSaveFailed(e))),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.lang.ingredientPortionSaved)),
      );
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.lang.ingredientPortionSaveFailed(e))),
      );
    }
  }
}

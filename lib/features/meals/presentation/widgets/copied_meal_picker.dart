import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../ingredients/presentation/widgets/ingredient_list_filter.dart';
import '../../data/model/copied_meal_type.dart';
import '../../data/providers/copied_meal_provider.dart';
import '../screens/meal_page.dart';
import 'copied_meal_ingredients_preview.dart';

class CopiedMealPicker extends HookConsumerWidget {
  const CopiedMealPicker({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = useState(initialQuery);
    final showTemplates = useState(false);
    final results = showTemplates.value
        ? ref.watch(copiedFromMealTemplateByQueryProvider(query.value))
        : ref.watch(copiedFromMealByQueryProvider(query.value));

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<bool>(
            segments: [
              ButtonSegment(
                value: false,
                label: Text(context.lang.copiedMealHistoryTab),
              ),
              ButtonSegment(
                value: true,
                label: Text(context.lang.copiedMealSavedTemplatesTab),
              ),
            ],
            selected: {showTemplates.value},
            onSelectionChanged: (selection) =>
                showTemplates.value = selection.single,
          ),
          const SizedBox(height: 16),
          IngredientListFilter(
            initialQuery: initialQuery,
            hintText: context.lang.copiedMealSearchHint,
            onQueryChanged: (value) {
              query.value = value;
            },
            padding: EdgeInsets.zero,
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: results.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => TextButton(
                  onPressed: () => ref.invalidate(
                    showTemplates.value
                        ? copiedFromMealTemplateByQueryProvider(query.value)
                        : copiedFromMealByQueryProvider(query.value),
                  ),
                  child: Text(context.lang.copiedMealLoadRetry),
                ),
                data: (items) {
                  final copiedMeals = [...items]
                    ..sort((a, b) => b.date.compareTo(a.date));
                  if (copiedMeals.isEmpty) {
                    return Text(context.lang.copiedMealNoResults);
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: copiedMeals.length,
                    itemBuilder: (context, index) {
                      final copiedMeal = copiedMeals[index];
                      return CopiedMealPickerTile(
                        key: ValueKey(
                          '${copiedMeal.runtimeType}:${copiedMeal.id}',
                        ),
                        copiedMeal: copiedMeal,
                        onPick: () => Navigator.of(context).pop(copiedMeal),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CopiedMealPickerTile extends HookConsumerWidget {
  final CopiedMealType copiedMeal;
  final VoidCallback onPick;

  const CopiedMealPickerTile({
    super.key,
    required this.copiedMeal,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canPreview = copiedMeal is CopiedMealFromMeal;

    final expanded = useState(false);
    return Column(
      children: [
        ListTile(
          title: CopiedMealPickerTitle(copiedMeal: copiedMeal),
          subtitle: Text(
            MaterialLocalizations.of(context).formatMediumDate(copiedMeal.date),
          ),
          trailing: Icon(
            expanded.value ? Icons.expand_less : Icons.expand_more,
          ),
          onTap: () => expanded.value = !expanded.value,
        ),
        if (expanded.value) ...[
          CopiedMealIngredientsPreview(source: copiedMeal, onUse: onPick),
          if (canPreview)
            TextButton(
              onPressed: () => _openPreview(context, ref),
              child: Text(context.lang.copiedMealHistoryDetails),
            ),
        ],
      ],
    );
  }

  Future<void> _openPreview(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final previewMealId = await ref.read(
      copiedMealPreviewTargetProvider(copiedMeal).future,
    );
    if (!context.mounted) {
      return;
    }
    if (previewMealId == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.lang.copiedMealNoPreview)),
      );
      return;
    }

    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(builder: (_) => MealPage(mealId: previewMealId)),
    );
  }
}

class CopiedMealPickerTitle extends StatelessWidget {
  final CopiedMealType copiedMeal;

  const CopiedMealPickerTitle({super.key, required this.copiedMeal});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CopiedMealPickerTypeBadge(copiedMeal: copiedMeal),
        const SizedBox(width: 8),
        Expanded(child: Text(copiedMeal.name)),
      ],
    );
  }
}

class CopiedMealPickerTypeBadge extends StatelessWidget {
  final CopiedMealType copiedMeal;

  const CopiedMealPickerTypeBadge({super.key, required this.copiedMeal});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isMeal = copiedMeal is CopiedMealFromMeal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isMeal
            ? context.lang.copiedMealMealBadge
            : context.lang.copiedMealTemplateBadge,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

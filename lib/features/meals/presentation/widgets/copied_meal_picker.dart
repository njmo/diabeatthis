import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../ingredients/presentation/widgets/ingredient_list_filter.dart';
import '../../data/model/copied_meal_type.dart';
import '../../data/providers/copied_meal_provider.dart';
import 'copied_meal_ingredients_preview.dart';
import 'copied_meal_picker_tile.dart';

class CopiedMealPicker extends HookConsumerWidget {
  const CopiedMealPicker({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = useState(initialQuery);
    final showTemplates = useState(false);
    final selected = useState<CopiedMealType?>(null);
    final scrollController = useScrollController();
    final results = showTemplates.value
        ? ref.watch(copiedFromMealTemplateByQueryProvider(query.value))
        : ref.watch(copiedFromMealByQueryProvider(query.value));
    final mediaQuery = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: (mediaQuery.size.height * 0.88 - mediaQuery.viewInsets.bottom)
              .clamp(200.0, mediaQuery.size.height),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: PopScope(
                    canPop: selected.value == null,
                    onPopInvokedWithResult: (didPop, result) {
                      if (!didPop) selected.value = null;
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Offstage(
                          offstage: selected.value != null,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                context.lang.copiedMealBrowseTitle,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                context.lang.copiedMealBrowseSubtitle,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 20),
                              IngredientListFilter(
                                initialQuery: initialQuery,
                                hintText: context.lang.copiedMealSearchHint,
                                onQueryChanged: (value) => query.value = value,
                                padding: EdgeInsets.zero,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      showTemplates.value
                                          ? context
                                                .lang
                                                .copiedMealSavedTemplatesTab
                                          : context.lang.copiedMealHistoryTab,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleSmall,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => showTemplates.value =
                                        !showTemplates.value,
                                    child: Text(
                                      showTemplates.value
                                          ? context.lang.copiedMealHistoryTab
                                          : context
                                                .lang
                                                .copiedMealSavedTemplatesTab,
                                    ),
                                  ),
                                ],
                              ),
                              Expanded(
                                child: results.when(
                                  loading: () => const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                  error: (error, stackTrace) => Center(
                                    child: TextButton(
                                      onPressed: () => ref.invalidate(
                                        showTemplates.value
                                            ? copiedFromMealTemplateByQueryProvider(
                                                query.value,
                                              )
                                            : copiedFromMealByQueryProvider(
                                                query.value,
                                              ),
                                      ),
                                      child: Text(
                                        context.lang.copiedMealLoadRetry,
                                      ),
                                    ),
                                  ),
                                  data: (items) {
                                    final copiedMeals = [
                                      ...items,
                                    ]..sort((a, b) => b.date.compareTo(a.date));
                                    if (copiedMeals.isEmpty) {
                                      return Center(
                                        child: Text(
                                          context.lang.copiedMealNoResults,
                                        ),
                                      );
                                    }
                                    return ListView.builder(
                                      controller: scrollController,
                                      itemCount: copiedMeals.length,
                                      itemBuilder: (context, index) =>
                                          CopiedMealPickerTile(
                                            copiedMeal: copiedMeals[index],
                                            onPreview: () {
                                              FocusScope.of(context).unfocus();
                                              selected.value =
                                                  copiedMeals[index];
                                            },
                                          ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (selected.value != null)
                          CopiedMealIngredientsPreview(
                            key: ValueKey(
                              '${selected.value.runtimeType}:${selected.value!.id}',
                            ),
                            source: selected.value!,
                            onBack: () => selected.value = null,
                            onUse: () =>
                                Navigator.of(context).pop(selected.value),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/search_text_field.dart';
import '../../../../common/widgets/status_info_card.dart';
import '../../../ingredients/data/drafts/ingredient_draft.dart';
import '../../../ingredients/data/models/ingredient_scan_result.dart';
import '../../../ingredients/presentation/widgets/ingredient_portion_suggestions.dart';
import '../../../meals/data/providers/add_ingredients_provider.dart';
import '../../data/drafts/portion_draft.dart';
import '../../data/drafts/portion_filter.dart';
import '../../data/mappers/portion_draft_mapper.dart';
import '../../data/providers/portion_provider.dart';
import 'portion_search_tile.dart';

class PortionSearch extends HookConsumerWidget {
  final IngredientDraft? ingredient;
  final VoidCallback? onCreatePortion;
  final String? createPortionLabel;
  final GlobalKey<FormState>? formKey;
  final List<RecognizedPortion> suggestions;
  final ValueChanged<RecognizedPortion>? onSuggestionSelected;

  const PortionSearch({
    this.ingredient,
    this.onCreatePortion,
    this.createPortionLabel,
    this.formKey,
    this.suggestions = const [],
    this.onSuggestionSelected,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = context.lang;
    final query = useState('');
    final queryController = useTextEditingController();
    final filter = ref.watch(portionFilterProvider);
    final selectedId = ref
        .watch(portionDraftProvider)
        .maybeMap(existing: (portion) => portion.id, orElse: () => null);
    final assigned = filter.maybeMap(
      byQueryForIngredient: (_) => true,
      orElse: () => false,
    );
    final portions = filter.map(
      all: (_) => ref.watch(portionsProvider),
      byQuery: (_) => ref.watch(portionsByQueryProvider(query.value)),
      byQueryForIngredient: (filter) => ref.watch(
        portionsByIngredientByQueryProvider(filter.ingredientId, query.value),
      ),
      allUnassignedForIngredient: (filter) => ref.watch(
        portionsNotInIngredientByQueryProvider(
          filter.ingredientId,
          query.value,
        ),
      ),
    );
    final selectionIsVisible =
        portions.asData?.value.any((portion) => portion.id == selectedId) ??
        false;
    final effectiveFormKey =
        formKey ?? ref.watch(mealIngredientFormKeyProvider);
    final chooseSuggestion = onSuggestionSelected;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: effectiveFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!assigned && chooseSuggestion != null)
              IngredientPortionSuggestions(
                suggestions: suggestions,
                onSelected: chooseSuggestion,
              ),
            if (query.value.isNotEmpty ||
                portions.asData?.value.isNotEmpty == true)
              SearchTextField(
                controller: queryController,
                hintText: lang.portionSearchLabel,
                onChanged: (value) => query.value = value,
              ),
            const SizedBox(height: 12),
            FormField<int>(
              validator: (_) => selectionIsVisible ? null : '',
              builder: (_) => portions.when(
                data: (data) {
                  if (data.isEmpty) {
                    return StatusInfoCard(
                      icon: Icons.search_off,
                      title: assigned
                          ? lang.portionNoMatchingForIngredient
                          : lang.portionNoMatching,
                    );
                  }
                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: data.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final portion = data[index];
                      return PortionSearchTile(
                        portion: portion.toSelection(),
                        ingredient: assigned ? ingredient : null,
                        selected: selectedId == portion.id,
                        onTap: () => ref
                            .read(portionDraftProvider.notifier)
                            .overrideDraft(portion.toSelection()),
                      );
                    },
                  );
                },
                error: (error, _) => StatusInfoCard(
                  icon: Icons.error_outline,
                  title: lang.portionLoadError(error.toString()),
                ),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            ),
            if (onCreatePortion != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  onCreatePortion!();
                  if (!assigned && query.value.trim().isNotEmpty) {
                    ref
                        .read(portionDraftProvider.notifier)
                        .setName(query.value.trim());
                  }
                },
                icon: const Icon(Icons.add),
                label: Text(
                  createPortionLabel ?? lang.addIngredientNewPortionTitle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

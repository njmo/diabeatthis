import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/portions/standard_portion_names.dart';
import '../../../ingredients/data/drafts/ingredient_draft.dart';
import '../../../ingredients/data/models/ingredient_scan_result.dart';
import '../../../portions/data/drafts/portion_draft.dart';
import '../../../portions/data/providers/portion_provider.dart';

final ingredientPortionsUseCaseProvider = Provider(
  (ref) => IngredientPortionsUseCase(
    loadCatalog: () async => [
      for (final portion in await ref.read(portionsProvider.future))
        PortionSelection.existing(
          id: portion.id,
          name: portion.name,
          unitHint: portion.unitHint,
        ),
    ],
    loadAssigned: (id) async => [
      for (final portion in await ref.read(
        portionsByIngredientByQueryProvider(id, '').future,
      ))
        PortionSelection.existing(
          id: portion.id,
          name: portion.name,
          unitHint: portion.unitHint,
        ),
    ],
    loadWeight: (ingredient, portion) =>
        ref.read(gramsPerPortionProvider(ingredient, portion).future),
  ),
);

class IngredientPortionsUseCase {
  const IngredientPortionsUseCase({
    required this.loadCatalog,
    required this.loadAssigned,
    required this.loadWeight,
  });
  final Future<List<PortionSelection>> Function() loadCatalog;
  final Future<List<PortionSelection>> Function(int) loadAssigned;
  final Future<double?> Function(IngredientDraft, PortionSelection) loadWeight;

  Future<PortionSelection> initialSelection(IngredientDraft ingredient) async {
    final id = ingredient.getIngredientIdOrNull();
    if (id == null) return const PortionSelection.empty();
    final assigned = await loadAssigned(id);
    return assigned.isEmpty ? const PortionSelection.empty() : assigned.first;
  }

  Future<ResolvedIngredientPortion> resolve(
    IngredientDraft ingredient,
    PortionSelection requested,
  ) async {
    final resolved = await matchingSelection(requested);
    final weight =
        resolved == null || ingredient.getIngredientIdOrNull() == null
        ? null
        : await loadWeight(ingredient, resolved);
    return ResolvedIngredientPortion(
      resolved ?? requested,
      weight,
      resolved != null,
    );
  }

  Future<PortionSelection?> matchingSelection(
    PortionSelection requested,
  ) async {
    final identity = requested.map(
      draft: (p) => (p.name, p.unitHint),
      existing: (p) => (p.name, p.unitHint),
      empty: (_) => ('', ''),
    );
    for (final selection in await loadCatalog()) {
      final matches = selection.map(
        draft: (_) => false,
        empty: (_) => false,
        existing: (p) =>
            namesMatchPortionSuggestion(p.name, identity.$1) &&
            p.unitHint.trim() == identity.$2.trim(),
      );
      if (matches) return selection;
    }
    return null;
  }

  Future<PortionSelection> fromSuggestion(RecognizedPortion suggestion) async {
    final requested = PortionSelection.draft(
      name: suggestion.name ?? '',
      unitHint: standardPortionWeightUnit,
    );
    return await matchingSelection(requested) ?? requested;
  }
}

class ResolvedIngredientPortion {
  const ResolvedIngredientPortion(this.selection, this.grams, this.exists);
  final PortionSelection selection;
  final double? grams;
  final bool exists;
}

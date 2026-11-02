import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../models/ingredient_scan_result.dart';

final ingredientPortionSuggestionsProvider =
    NotifierProvider<
      IngredientPortionSuggestionsNotifier,
      List<RecognizedPortion>
    >(IngredientPortionSuggestionsNotifier.new);

/// Transient import evidence; accepting a suggestion still requires confirmation.
class IngredientPortionSuggestionsNotifier
    extends Notifier<List<RecognizedPortion>> {
  @override
  List<RecognizedPortion> build() => const [];

  void setSuggestions(List<RecognizedPortion> suggestions) {
    state = List.unmodifiable(
      suggestions.where((portion) {
        final grams = portion.grams;
        return portion.name?.trim().isNotEmpty == true &&
            grams != null &&
            grams.isFinite &&
            grams > 0;
      }),
    );
  }

  void clear() => state = const [];
}

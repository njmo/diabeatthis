import 'package:flutter_riverpod/flutter_riverpod.dart';

final ingredientSearchQueryProvider =
    NotifierProvider<IngredientSearchQuery, String>(IngredientSearchQuery.new);

class IngredientSearchQuery extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
}

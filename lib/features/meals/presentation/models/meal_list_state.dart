import '../../../../core/domain/model/ingredient.dart';
import '../../data/models/meal_list_filter.dart';

class MealListState {
  final MealListFilter filter;
  final List<Ingredient> selectedIngredients;
  final int visibleLimit;

  const MealListState({
    required this.filter,
    required this.selectedIngredients,
    required this.visibleLimit,
  });

  const MealListState.initial()
    : filter = const MealListFilter.recent(),
      selectedIngredients = const [],
      visibleLimit = mealListPageSize;

  String get query {
    return filter.map(
      recent: (_) => '',
      byQuery: (filter) => filter.query,
      byIngredients: (_) => '',
    );
  }

  MealListState copyWith({
    MealListFilter? filter,
    List<Ingredient>? selectedIngredients,
    int? visibleLimit,
  }) {
    return MealListState(
      filter: filter ?? this.filter,
      selectedIngredients: selectedIngredients ?? this.selectedIngredients,
      visibleLimit: visibleLimit ?? this.visibleLimit,
    );
  }
}

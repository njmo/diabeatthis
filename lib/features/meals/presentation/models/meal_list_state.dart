import '../../../../core/domain/model/ingredient.dart';
import '../../../../core/domain/model/meal.dart' as domain;
import '../../data/models/meal_list_filter.dart';

class MealListState {
  final MealListFilter filter;
  final List<Ingredient> selectedIngredients;
  final List<domain.Meal> meals;
  final int nextPage;
  final bool hasMore;
  final bool isRefreshing;
  final bool isLoadingMore;
  final String? loadMoreError;

  const MealListState({
    required this.filter,
    required this.selectedIngredients,
    required this.meals,
    required this.nextPage,
    required this.hasMore,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.loadMoreError,
  });

  const MealListState.initial()
    : filter = const MealListFilter.recent(),
      selectedIngredients = const [],
      meals = const [],
      nextPage = 0,
      hasMore = true,
      isRefreshing = false,
      isLoadingMore = false,
      loadMoreError = null;

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
    List<domain.Meal>? meals,
    int? nextPage,
    bool? hasMore,
    bool? isRefreshing,
    bool? isLoadingMore,
    String? loadMoreError,
    bool clearLoadMoreError = false,
  }) {
    return MealListState(
      filter: filter ?? this.filter,
      selectedIngredients: selectedIngredients ?? this.selectedIngredients,
      meals: meals ?? this.meals,
      nextPage: nextPage ?? this.nextPage,
      hasMore: hasMore ?? this.hasMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      loadMoreError: clearLoadMoreError
          ? null
          : loadMoreError ?? this.loadMoreError,
    );
  }
}

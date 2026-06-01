import '../../data/models/meal_list_filter.dart';

class MealListState {
  final MealListFilter filter;
  final int visibleLimit;

  const MealListState({required this.filter, required this.visibleLimit});

  const MealListState.initial()
    : filter = const MealListFilter.recent(),
      visibleLimit = mealListPageSize;

  String get query => filter.query;

  MealListState copyWith({MealListFilter? filter, int? visibleLimit}) {
    return MealListState(
      filter: filter ?? this.filter,
      visibleLimit: visibleLimit ?? this.visibleLimit,
    );
  }
}

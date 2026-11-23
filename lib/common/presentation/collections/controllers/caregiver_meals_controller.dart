import '../../../../core/domain/model/meal.dart';
import '../../../meal/meal_category.dart';
import '../models/collection_state.dart';
import 'meals_controller.dart';

class CaregiverMealsController implements MealsController {
  CaregiverMealsController({
    required List<Map<String, dynamic>> rows,
    required this.open,
    required this.onRetry,
    this.onLoadMore,
    bool loading = false,
    bool failed = false,
    bool loadingMore = false,
    bool hasMore = false,
    bool preserveOrder = false,
    String query = '',
    MealCategory? category,
  }) : state = CollectionState(
         items: _ordered(
           rows
               .where((r) => r['kind'] == 'meals' && r['deleted'] != true)
               .map((r) {
                 final p = r['payload'] as Map;
                 return Meal(
                   id: p['id'] as int,
                   name: p['name'] as String,
                   status: p['status'] as String,
                   purpose: MealPurpose.fromStorage(p['purpose'] as String?),
                   category: MealCategory.fromStorage(p['category'] as String?),
                   plannedAt: p['planned_at'] is int
                       ? DateTime.fromMillisecondsSinceEpoch(
                           p['planned_at'] as int,
                         )
                       : null,
                   plannedDay: p['planned_day'] as String?,
                   createdAt: p['created_at'] is int
                       ? DateTime.fromMillisecondsSinceEpoch(
                           p['created_at'] as int,
                         )
                       : null,
                   notes: p['notes'] as String?,
                 );
               })
               .where(
                 (m) =>
                     m.name.toLowerCase().contains(
                       query.trim().toLowerCase(),
                     ) &&
                     (category == null || m.category == category),
               )
               .toList(),
           preserveOrder,
         ),
         loading: loading,
         failed: failed,
         loadingMore: loadingMore,
         hasMore: hasMore,
       );
  @override
  final CollectionState<Meal> state;
  @override
  final void Function(Meal)? open;
  @override
  Future<bool> Function(Meal)? get delete => null;
  final void Function() onRetry;
  final void Function()? onLoadMore;
  @override
  void retry() => onRetry();
  @override
  void loadMore() => onLoadMore?.call();
}

List<Meal> _ordered(List<Meal> meals, bool preserveOrder) {
  if (!preserveOrder) {
    meals.sort((a, b) => _sortTime(b).compareTo(_sortTime(a)));
  }
  return meals;
}

DateTime _sortTime(Meal meal) =>
    meal.plannedAt ??
    DateTime.tryParse(meal.plannedDay ?? '') ??
    meal.createdAt ??
    DateTime.fromMillisecondsSinceEpoch(0);

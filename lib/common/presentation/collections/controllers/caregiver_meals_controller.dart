import '../../../../core/domain/model/meal.dart';
import '../../../meal/meal_category.dart';
import '../models/collection_state.dart';
import 'meals_controller.dart';

class CaregiverMealsController implements MealsController {
  CaregiverMealsController({
    required List<Map<String, dynamic>> rows,
    required this.open,
    required this.onRetry,
    bool loading = false,
    bool failed = false,
    String query = '',
    MealCategory? category,
  }) : state = CollectionState(
         items:
             rows
                 .where((r) => r['kind'] == 'meals' && r['deleted'] != true)
                 .map((r) {
                   final p = r['payload'] as Map;
                   return Meal(
                     id: p['id'] as int,
                     name: p['name'] as String,
                     status: p['status'] as String,
                     purpose: MealPurpose.fromStorage(p['purpose'] as String?),
                     category: MealCategory.fromStorage(
                       p['category'] as String?,
                     ),
                     plannedAt: DateTime.fromMillisecondsSinceEpoch(
                       p['planned_at'] as int,
                     ),
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
                 .toList()
               ..sort((a, b) => b.plannedAt!.compareTo(a.plannedAt!)),
         loading: loading,
         failed: failed,
       );
  @override
  final CollectionState<Meal> state;
  @override
  final void Function(Meal)? open;
  @override
  Future<bool> Function(Meal)? get delete => null;
  final void Function() onRetry;
  @override
  void retry() => onRetry();
  @override
  void loadMore() {}
}

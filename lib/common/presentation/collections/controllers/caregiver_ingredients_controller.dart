import '../../../../core/domain/model/ingredient.dart';
import '../../../family_sync/presentation/models/family_ingredient_view.dart';
import '../models/collection_state.dart';
import 'ingredients_controller.dart';

class CaregiverIngredientsController implements IngredientsController {
  CaregiverIngredientsController({
    required List<Map<String, dynamic>> rows,
    required this.open,
    required this.onRetry,
    bool loading = false,
    bool failed = false,
    String query = '',
  }) : state = CollectionState(
         items:
             rows
                 .where(
                   (r) => r['kind'] == 'ingredients' && r['deleted'] != true,
                 )
                 .map(familyIngredientView)
                 .where(
                   (item) => '${item.name} ${item.brand ?? ''}'
                       .toLowerCase()
                       .contains(query.trim().toLowerCase()),
                 )
                 .toList()
               ..sort((a, b) => a.name.compareTo(b.name)),
         loading: loading,
         failed: failed,
       );
  @override
  final CollectionState<Ingredient> state;
  @override
  final void Function(Ingredient)? open;
  final void Function() onRetry;
  @override
  void retry() => onRetry();
  @override
  void loadMore() {}
}

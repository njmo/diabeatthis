import '../../core/domain/model/ingredient.dart';
import '../backend/authenticated_callable_transport.dart';
import '../ingredient_catalog/ingredient_identity.dart';
import '../ingredient_catalog/ingredient_search_item.dart';
import '../ingredient_catalog/local_ingredient_search_repository.dart';
import 'presentation/models/family_ingredient_view.dart';

class ChildIngredientSearchItem extends IngredientSearchItem {
  ChildIngredientSearchItem(this.ingredient)
    : super(
        identity: IngredientIdentity(
          source: IngredientSource.local,
          sourceId: '${ingredient.id}',
        ),
        name: ingredient.name,
        details: ingredient.brand ?? '',
        localIngredientId: ingredient.id,
        isReference: ingredient.isReference,
      );

  final Ingredient ingredient;
}

class ChildIngredientSearchRepository
    implements LocalIngredientSearchRepository {
  const ChildIngredientSearchRepository({
    required this.transport,
    required this.caregiverUid,
    required this.childUid,
    required this.isCurrent,
  });

  final AuthenticatedCallableTransport transport;
  final String caregiverUid;
  final String childUid;
  final bool Function() isCurrent;

  @override
  Future<List<IngredientSearchItem>> search(
    String query, {
    int limit = 20,
  }) async {
    if (!RegExp(r'[\p{L}\p{N}]{2}', unicode: true).hasMatch(query)) return [];
    final response = await _call({'query': query});
    return [
      for (final row in (response['records'] as List).take(limit))
        ChildIngredientSearchItem(familyIngredientView(row as Map)),
    ];
  }

  Future<double?> gramsPerPiece(int id) async =>
      ((await _call({'ingredientId': id}))['gramsPerPiece'] as num?)
          ?.toDouble();

  Future<({String sourceId, List<Map<String, dynamic>> rows})>
  quickTreatmentEditorRows({int? ingredientId}) async {
    final response = await _call(
      ingredientId == null
          ? {'quickFoodsEditor': true}
          : {'ingredientDetailsId': ingredientId},
    );
    return (
      sourceId: response['sourceId'] as String,
      rows: [
        for (final row in response['records'] as List)
          Map<String, dynamic>.from(row as Map),
      ],
    );
  }

  Future<({List<Map<String, dynamic>> items, bool canEdit})>
  quickFoods() async {
    final response = await _call({'quickFoods': true});
    return (
      canEdit: response['canEdit'] == true,
      items: [
        for (final item in response['foods'] as List)
          Map<String, dynamic>.from(item as Map),
      ],
    );
  }

  Future<Map<String, dynamic>> _call(Map<String, Object?> data) async {
    final response = await transport.call(
      'searchFamilyMirrorIngredients',
      data,
      expectedUid: caregiverUid,
      allowRequest: () async => isCurrent(),
    );
    if (!isCurrent() || response['ownerUid'] != childUid) {
      throw StateError('The selected child changed');
    }
    return response;
  }
}

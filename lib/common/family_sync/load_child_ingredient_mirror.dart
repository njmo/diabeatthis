import '../backend/authenticated_callable_transport.dart';

/// Loads the ingredient projection pinned to the child selected in the chat.
Future<List<Map<String, dynamic>>> loadChildIngredientMirror({
  required AuthenticatedCallableTransport transport,
  required String caregiverUid,
  required String childUid,
  required bool Function() isCurrent,
}) async {
  final ingredients = <String, Map<String, dynamic>>{};
  var cursor = 0;
  String? source;
  for (var page = 0; page < 200; page++) {
    final response = await transport.call(
      'fetchFamilyMirror',
      {'after': cursor},
      expectedUid: caregiverUid,
      allowRequest: () async => isCurrent(),
    );
    final responseSource = response['sourceId'];
    if (!isCurrent() || response['ownerUid'] != childUid) {
      throw StateError('The selected child mirror changed');
    }
    final records = response['records'] as List;
    if (source == null &&
        responseSource == null &&
        records.isEmpty &&
        response['hasMore'] == false) {
      return const [];
    }
    if (responseSource is! String ||
        (source != null && responseSource != source)) {
      throw StateError('The selected child mirror changed');
    }
    source = responseSource;
    for (final raw in records) {
      final row = Map<String, dynamic>.from(raw as Map);
      final kind = row['kind'];
      if (kind != 'ingredients' && kind != 'ingredientOrigins') continue;
      final key = '$kind/${row['id']}';
      if (row['deleted'] == true) {
        ingredients.remove(key);
      } else {
        ingredients[key] = row;
      }
    }
    if (response['hasMore'] != true) return ingredients.values.toList();
    final nextCursor = response['cursor'] as int;
    if (nextCursor <= cursor) break;
    cursor = nextCursor;
  }
  throw StateError('The selected child ingredient mirror is incomplete');
}

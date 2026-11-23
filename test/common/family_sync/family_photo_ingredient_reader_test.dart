import 'dart:convert';

import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:diabeatthis/common/family_sync/child_ingredient_search_repository.dart';
import 'package:diabeatthis/common/family_sync/photo/family_photo_ingredient_reader.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'photo search only loads versions for selected child ingredients',
    () async {
      final requests = <Map<String, dynamic>>[];
      var source = 'source';
      var carbs = 12;
      Map<String, dynamic> ingredient(int id) => {
        'kind': 'ingredients',
        'id': '$id',
        'revision': 4,
        'payload': {
          'name': 'Bread $id',
          'carbs_per_100g': carbs,
          'fat_per_100g': 1,
          'protein_per_100g': 2,
          'fiber_per_100g': 3,
        },
      };
      final transport = AuthenticatedCallableTransport(
        client: MockClient((request) async {
          expect(
            request.url.pathSegments.last,
            'searchFamilyMirrorIngredients',
          );
          final data = (jsonDecode(request.body) as Map)['data'] as Map;
          requests.add(Map<String, dynamic>.from(data));
          final id = data['ingredientDetailsId'] as int?;
          return http.Response(
            jsonEncode({
              'result': {
                'ownerUid': 'child',
                'sourceId': source,
                'records': id == null
                    ? [ingredient(1), ingredient(2)]
                    : [ingredient(id)],
              },
            }),
            200,
          );
        }),
        projectId: 'test',
        currentUid: () => 'parent',
        identity: () async => const CallableIdentity('parent', 'token', 'app'),
      );
      final reader = FamilyPhotoIngredientReader(
        ChildIngredientSearchRepository(
          transport: transport,
          caregiverUid: 'parent',
          childUid: 'child',
          isCurrent: () => true,
        ),
        source,
      );

      expect(requests, isEmpty);
      expect(await reader.search('Bread'), hasLength(2));
      expect((await reader.get(2)).carbsPer100g, 12);
      expect(requests, [
        {'query': 'Bread'},
      ]);
      expect(await reader.baseRows({}), isEmpty);
      expect((await reader.baseRows({2})).single['revision'], 4);
      expect(requests.last, {'ingredientDetailsId': 2});
      carbs = 14;
      await expectLater(reader.baseRows({2}), throwsStateError);
      carbs = 12;
      source = 'another-source';
      await expectLater(reader.baseRows({2}), throwsStateError);
    },
  );
}

import 'dart:convert';

import 'package:diabeatthis/common/ingredient_catalog/http_catalog_callable_transport.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_catalog_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'callable wraps data and sends App Check to configured project',
    () async {
      final client = MockClient((request) async {
        expect(
          request.url.toString(),
          'https://europe-west1-project.cloudfunctions.net/searchIngredients',
        );
        expect(request.headers['X-Firebase-AppCheck'], 'verified-token');
        expect(jsonDecode(request.body), {
          'data': {'query': 'rice'},
        });
        return http.Response(
          jsonEncode({
            'result': {'items': []},
          }),
          200,
        );
      });
      final transport = HttpCatalogCallableTransport(
        client: client,
        projectId: 'project',
        appCheckToken: () async => 'verified-token',
      );
      expect(await transport.call('searchIngredients', {'query': 'rice'}), {
        'items': [],
      });
    },
  );
  test('missing App Check never sends unauthenticated request', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      return http.Response('{}', 200);
    });
    final transport = HttpCatalogCallableTransport(
      client: client,
      projectId: 'project',
      appCheckToken: () async => null,
    );
    await expectLater(
      transport.call('searchIngredients', {}),
      throwsA(
        isA<IngredientCatalogException>().having(
          (e) => e.failure,
          'failure',
          IngredientCatalogFailure.unauthorized,
        ),
      ),
    );
    expect(calls, 0);
  });
  test(
    'expired release cursor is distinguished from offline failure',
    () async {
      final client = MockClient(
        (request) async => http.Response(
          jsonEncode({
            'error': {'status': 'FAILED_PRECONDITION'},
          }),
          400,
        ),
      );
      final transport = HttpCatalogCallableTransport(
        client: client,
        projectId: 'project',
        appCheckToken: () async => 'token',
      );
      await expectLater(
        transport.call('searchIngredients', {}),
        throwsA(
          isA<IngredientCatalogException>().having(
            (e) => e.failure,
            'failure',
            IngredientCatalogFailure.staleCursor,
          ),
        ),
      );
    },
  );
}

import 'package:diabeatthis/common/ingredient_catalog/http_catalog_callable_transport.dart';
import 'package:diabeatthis/common/ingredient_catalog/ingredient_catalog_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  for (final status in [404, 502, 503]) {
    test(
      'HTTP $status HTML response is catalog unavailable rather than malformed ingredient data',
      () async {
        final transport = HttpCatalogCallableTransport(
          client: MockClient(
            (request) async =>
                http.Response('<html>Service unavailable</html>', status),
          ),
          projectId: 'project',
          appCheckToken: () async => 'token',
        );
        await expectLater(
          transport.call('searchIngredients', {'query': 'ryz'}),
          throwsA(
            isA<IngredientCatalogException>().having(
              (error) => error.failure,
              'failure',
              IngredientCatalogFailure.unavailable,
            ),
          ),
        );
      },
    );
  }
}
